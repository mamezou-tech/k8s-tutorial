variable "env" {
  type = string
}

variable "oidc_provider_url" {
  type    = string
}

variable "eks_cluster_name" {
  type    = string
  default = "mz-k8s"
}

variable "enable_otel" {
  type = bool
  default = false
}
