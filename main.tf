provider "aws" {
  region  = "ap-northeast-1"
  version = "3.48.0"
}

terraform {
  required_version = "0.13.2"
}

variable "aws_account_id" {}
variable "region" {}
variable "environment_name" {}

locals {
  project_name = "terraform-study-s3-sqs-lambda-sns"
}

resource "aws_sns_topic" "normal" {
  name = "${var.environment_name}-normal"

  tags = {
    Name = local.project_name
  }
}

resource "aws_sns_topic" "dlq" {
  name = "${var.environment_name}-dlq"

  tags = {
    Name = local.project_name
  }
}

# S3
resource "aws_s3_bucket" "terraform_study" {
  bucket = local.project_name
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = local.project_name
  }
}
