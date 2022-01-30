# Terraform自体の設定
terraform {
  required_version = "~> 1.0.8"
  # リモートステートの設定
  backend "s3" {
    bucket = "mz-terraform"
    key    = "eks-state"
    region = "ap-northeast-1"
  }
  # 実行するProviderの条件
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.71.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.5.0"
    }
  }
}

provider "aws" {}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "mz-eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  # enable AWS Load Balancer Controller subnet-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.0.5"
  cluster_version = "1.21"
  cluster_name    = "mz-k8s"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  enable_irsa     = true
  eks_managed_node_groups = {
    mz_node = {
      desired_size   = 2
      instance_types = ["m5.large"]
    }
  }
  node_security_group_additional_rules = {
    admission_webhook = {
      description                   = "Admission Webhook"
      protocol                      = "tcp"
      from_port                     = 0
      to_port                       = 65535
      type                          = "ingress"
      source_cluster_security_group = true
    }

    # Node to node communications
    ingress_node_communications = {
      description = "Ingress Node to node"
      protocol    = "tcp"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
    egress_node_communications = {
      description = "Egress Node to node"
      protocol    = "tcp"
      from_port   = 0
      to_port     = 65535
      type        = "egress"
      self        = true
    }

    # cert-manager require ACME self check using http protocol
    egress_http_internet = {
      description = "Egress HTTP to internet"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    # flux require ssh access to clone git repository
    egress_ssh_internet = {
      description = "Egress SSH to internet"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

output "aws_auth_config_map" {
  value = module.eks.aws_auth_configmap_yaml
}

output "eks_oidc_provider_url" {
  value = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# enable IRSA for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_loadbalancer_controller" {
  name   = "EKSIngressAWSLoadBalancerController"
  policy = file("${path.module}/alb-ingress-policy.json")
}

module "iam_assumable_role_admin" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 4.0"

  create_role                  = true
  role_name                    = "EKSIngressAWSLoadBalancerController"
  provider_url                 = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns             = [aws_iam_policy.aws_loadbalancer_controller.arn]
  oidc_subjects_with_wildcards = ["system:serviceaccount:*:*"]
}

resource "kubernetes_service_account" "aws_loadbalancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_assumable_role_admin.iam_role_arn
    }
  }
}

# for external-dns
resource "aws_iam_policy" "external_dns" {
  name   = "ExternalDNSRecordSetChange"
  policy = file("${path.module}/external-dns-policy.json")
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

module "external_dns" {
  source           = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version          = "~> 4.0"
  create_role      = true
  role_name        = "EKSExternalDNS"
  provider_url     = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [aws_iam_policy.external_dns.arn]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${kubernetes_namespace.external_dns.metadata[0].name}:external-dns"
  ]
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_dns.iam_role_arn
    }
  }
}

# for EBS SCI Driver
resource "aws_iam_policy" "ebs_csi" {
  name   = "AWSEBSControllerIAMPolicy"
  policy = file("${path.module}/ebs-controller-policy.json")
}

module "ebs_csi" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "EKSEBSCsiDriver"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.ebs_csi.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-ebs-controller"]
}

resource "kubernetes_service_account" "ebs_csi" {
  metadata {
    name      = "aws-ebs-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.ebs_csi.iam_role_arn
    }
  }
}

# for EFS SCI Driver
resource "aws_iam_policy" "efs_csi_controller" {
  name   = "AWSEFSControllerIAMPolicy"
  policy = file("${path.module}/efs-controller-policy.json")
}

module "efs_csi_controller" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "EKSEFSCsiController"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.efs_csi_controller.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-efs-controller"]
}

resource "kubernetes_service_account" "efs_csi_controller" {
  metadata {
    name      = "aws-efs-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.efs_csi_controller.iam_role_arn
    }
  }
}

resource "aws_iam_policy" "efs_csi_node" {
  name   = "AWSEFSNodeIAMPolicy"
  policy = file("${path.module}/efs-node-policy.json")
}

module "efs_csi_node" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "EKSEFSCsiNode"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.efs_csi_node.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-efs-node"]
}

resource "kubernetes_service_account" "efs_csi_node" {
  metadata {
    name      = "aws-efs-node"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.efs_csi_node.iam_role_arn
    }
  }
}

# for EFS
resource "aws_efs_file_system" "this" {
  tags = {
    Name = "k8s-efs-test"
  }
  encrypted = true
}

resource "aws_security_group" "efs_mount_target" {
  name        = "efs-eks-sg"
  description = "EFS Mount point for EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_mount_target" "this" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_mount_target.id]
}
