provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Name = local.project_name
    }
  }
}


terraform {
  required_version = "0.13.2"
  required_providers {
    aws = {
      version = "3.48.0"
      source  = "hashicorp/aws"
    }
  }
}

locals {
  project_name = "terraform-study-s3-sqs-lambda-sns"
}

# S3
resource "aws_s3_bucket" "event_source" {
  bucket        = local.project_name
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "${local.project_name}-lifecycle-rule"
    enabled = true

    expiration {
      days = 60
    }
    noncurrent_version_expiration {
      days = 10
    }
  }
}

module "s3_sqs_lambda_sns" {
  for_each = var.function_uri_list

  source                = "./modules/s3_sqs_lambda_sns"
  lambda_function_name  = each.key
  lambda_function_image = each.value
  region                = var.region
  project_name          = local.project_name
  source_bucket_name    = aws_s3_bucket.event_source.id
}


# S3 event
# create resource out of above module,
# because aws_s3_bucket_notification resource only support a single configuration
resource "aws_s3_bucket_notification" "event_source" {
  bucket = aws_s3_bucket.event_source.id

  dynamic "queue" {
    for_each = tomap(module.s3_sqs_lambda_sns)
    content {
      id            = queue.value.resource_name
      queue_arn     = queue.value.queue_arn
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "${queue.key}/"
    }
  }
}
