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
# 完了タスク出力レポートバッチ
resource "aws_ecr_repository" "task_reporter" {
  name = "mamezou-tech/task-reporter"
}
