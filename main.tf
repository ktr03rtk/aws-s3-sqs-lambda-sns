provider "aws" {
  region  = "ap-northeast-1"
  version = "3.48.0"
}

terraform {
  required_version = "0.13.2"
}

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
  name = "${var.environment_name}-dlq-subscription-sns"

  tags = {
    Name = local.project_name
  }
}

# S3
resource "aws_s3_bucket" "event_source" {
  bucket = local.project_name
  acl    = "private"

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

  tags = {
    Name = local.project_name
  }
}

# dlq
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.project_name}-${var.environment_name}-dlq"
  message_retention_seconds = 1209600

  tags = {
    Name = local.project_name
  }
}

# s3 event queue
resource "aws_sqs_queue" "s3_event_queue" {
  name                       = "${local.project_name}-${var.environment_name}-s3-event-queue"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 4
  })

  tags = {
    Name = local.project_name
  }
}

data "aws_caller_identity" "current" {}

resource "aws_sqs_queue_policy" "s3_event_queue" {
  queue_url = aws_sqs_queue.s3_event_queue.id

  policy = templatefile(
    "./s3_event_sqs_policy.json",
    {
      queue_arn               = aws_sqs_queue.s3_event_queue.arn
      source_bucket_name      = aws_s3_bucket.event_source.id
      bucket_owner_account_id = data.aws_caller_identity.current.account_id
    }
  )

}
