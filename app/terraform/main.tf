terraform {
  required_version = "~> 1.0.8"
  # リモートステートの設定
  backend "s3" {
    bucket = "mz-terraform"
    key    = "task-tool-state"
    region = "ap-northeast-1"
  }
  # 実行するProviderの条件
  required_providers {
    aws        = {
      source  = "hashicorp/aws"
      version = "~> 3.62"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.5.0"
    }
  }
}

provider "aws" {}

# タスク管理API
resource "aws_ecr_repository" "task_service" {
  name = "mamezou-tech/task-service"
}
# タスク管理UI(静的リソース)
resource "aws_ecr_repository" "task_web" {
  name = "mamezou-tech/task-web"
}
# 完了タスクレポート出力バッチ
resource "aws_ecr_repository" "task_reporter" {
  name = "mamezou-tech/task-reporter"
}

resource "aws_dynamodb_table" "tasks" {
  name         = "task-tool-${var.env}-tasks"
  hash_key     = "task_id"
  attribute {
    name = "task_id"
    type = "S"
  }
  attribute {
    name = "start_at"
    type = "N"
  }
  attribute {
    name = "updated_at"
    type = "N"
  }
  attribute {
    name = "user_name"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }
  global_secondary_index {
    name            = "user_index"
    hash_key        = "user_name"
    range_key       = "start_at"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "status_index"
    hash_key        = "status"
    range_key       = "updated_at"
    projection_type = "ALL"
  }
  billing_mode = "PAY_PER_REQUEST"
}

resource "aws_s3_bucket" "task_reports" {
  bucket = "task-tool-${var.env}-completed-task-report-bucket"
}

// IRSA
data "aws_eks_cluster" "eks" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.env
  }
}

data "aws_caller_identity" "current" {}

# for AWS Distro for OpenTelemetry

module "adot_collector" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "ADOTCollector"
  provider_url                  = var.oidc_provider_url
  role_policy_arns              = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"] # AWS managed policy
  oidc_fully_qualified_subjects = ["system:serviceaccount:amzn-cloudwatch-metrics:adot-collector"]
}

#resource "kubernetes_namespace" "cloudwatch_metrics" {
#  metadata {
#    name = "amzn-cloudwatch-metrics"
#  }
#}
#
#resource "kubernetes_service_account" "adot_collector" {
#  metadata {
#    namespace = kubernetes_namespace.cloudwatch_metrics.metadata[0].name
#    name = "adot-collector"
#    annotations = {
#      "eks.amazonaws.com/role-arn" = module.adot_collector.iam_role_arn
#    }
#  }
#}

data "aws_iam_policy_document" "app_task_table" {
  statement {
    actions   = [
      "dynamodb:List*",
      "dynamodb:DescribeReservedCapacity*",
      "dynamodb:DescribeLimits",
      "dynamodb:DescribeTimeToLive"
    ]
    resources = [
      aws_dynamodb_table.tasks.arn
    ]
  }
  statement {
    actions   = [
      "dynamodb:BatchGet*",
      "dynamodb:DescribeTable",
      "dynamodb:Get*",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWrite*",
      "dynamodb:PutItem"
    ]
    resources = [
      aws_dynamodb_table.tasks.arn,
      "${aws_dynamodb_table.tasks.arn}/index/*"
    ]
  }
}

resource "aws_iam_policy" "app_task_table" {
  name   = "DynamoDBTaskTablePolicy"
  policy = data.aws_iam_policy_document.app_task_table.json
}

resource "aws_iam_policy" "eks_aodt_collector" {
  name   = "EKSADOTCollector"
  policy = file("${path.module}/otel-collector-policy.json")
}

module "task_service" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_path                     = "/app/"
  role_name                     = "TaskService"
  provider_url                  = var.oidc_provider_url
#  role_policy_arns              = concat([aws_iam_policy.app_task_table.arn], var.enable_otel ? [aws_iam_policy.eks_aodt_collector.arn] : [])
  role_policy_arns              = [aws_iam_policy.app_task_table.arn, data.aws_iam_policy.xray_write_access.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.env}:task-service"]
}

resource "kubernetes_service_account" "task_service" {
  metadata {
    name        = "task-service"
    namespace   = var.env
    annotations = {
      "eks.amazonaws.com/role-arn" = module.task_service.iam_role_arn
    }
  }
}

data "aws_iam_policy_document" "app_task_report_bucket" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.task_reports.arn]
  }
  statement {
    actions   = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads"
    ]
    resources = ["${aws_s3_bucket.task_reports.arn}/*"]
  }
}

resource "aws_iam_policy" "app_task_reports" {
  name   = "S3TaskReportsPolicy"
  policy = data.aws_iam_policy_document.app_task_report_bucket.json
}

module "task_reporter" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_path                     = "/app/"
  role_name                     = "TaskReporter"
  provider_url                  = var.oidc_provider_url
  role_policy_arns              = [aws_iam_policy.app_task_table.arn, aws_iam_policy.app_task_reports.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.env}:task-reporter"]
}

resource "kubernetes_service_account" "task_reporter" {
  metadata {
    name        = "task-reporter"
    namespace   = var.env
    annotations = {
      "eks.amazonaws.com/role-arn" = module.task_reporter.iam_role_arn
    }
  }
}

data "aws_region" "this" {}
data "aws_caller_identity" "this" {}

# OpenSearch
#resource "aws_elasticsearch_domain" "this" {
#  domain_name           = "task-tool-log"
#  elasticsearch_version = "OpenSearch_1.1"
#  ebs_options {
#    ebs_enabled = true
#    volume_type = "gp2"
#    volume_size = 30
#  }
#  node_to_node_encryption {
#    enabled = true
#  }
#  encrypt_at_rest {
#    enabled = true
#  }
#  domain_endpoint_options {
#    enforce_https = true
#    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
#  }
#  advanced_security_options {
#    enabled = true
#    internal_user_database_enabled = true
#    master_user_options {
#      master_user_name = "admin"
#      master_user_password = "MZ-pass-123"
#    }
#  }
#}
#
#resource "aws_elasticsearch_domain_policy" "this" {
#  domain_name     = aws_elasticsearch_domain.this.domain_name
#  access_policies = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Effect    = "Allow",
#        Principal = {
#          AWS = "*"
#        },
#        Action = "es:ESHttp*"
#        Resource = "arn:aws:es:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:domain/${aws_elasticsearch_domain.this.domain_name}/*"
#      }
#    ]
#  })
#}

# Fluent Bit
#data "aws_iam_policy_document" "opensearch" {
#  version = "2012-10-17"
#  statement {
#    actions = ["es:ESHttp*"]
#    effect = "Allow"
#    resources = ["arn:aws:es:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:domain/${aws_elasticsearch_domain.this.domain_name}/*"]
#  }
#}
#
#resource "aws_iam_policy" "opensearch" {
#  name = "TaskToolOpenSearchAccess"
#  policy = data.aws_iam_policy_document.opensearch.json
#}

data "aws_iam_policy" "cloudwatch_agent_server_policy" {
  name = "CloudWatchAgentServerPolicy"
}

module "fluentbit" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "FluentBit"
  provider_url                  = var.oidc_provider_url
  role_policy_arns              = [data.aws_iam_policy.cloudwatch_agent_server_policy.arn]
#  role_policy_arns              = [aws_iam_policy.opensearch.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:fluent-bit:fluent-bit"]
}

resource "kubernetes_namespace" "fluentbit" {
  metadata {
    name = "fluent-bit"
  }
}

resource "kubernetes_service_account" "fluentbit" {
  metadata {
    namespace = "fluent-bit"
    name = "fluent-bit"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.fluentbit.iam_role_arn
    }
  }
}

# for AWS X-Ray Manged Policy
data "aws_iam_policy" "xray_write_access" {
  name = "AWSXRayDaemonWriteAccess"
}

module "adot_xray_collector" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "ADOTXrayCollector"
  provider_url                  = var.oidc_provider_url
  role_policy_arns              = [data.aws_iam_policy.xray_write_access.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:tracing:otel-web-collector"]
}

resource "kubernetes_service_account" "otel_web_xray_collector" {
  metadata {
    name = "otel-web-collector"
    namespace = "tracing"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.adot_xray_collector.iam_role_arn
    }
  }
}
