provider "aws" {
  region  = "ap-northeast-1"
  version = "3.48.0"

  default_tags {
    tags = {
      Name = local.project_name
    }
  }
}

terraform {
  required_version = "0.13.2"
}

locals {
  project_name = "terraform-study-s3-sqs-lambda-sns"
}

resource "aws_sns_topic" "success" {
  name = "${var.environment_name}-success"
}

resource "aws_sns_topic" "dlq" {
  name = "${var.environment_name}-dlq-subscription-sns"
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
}

resource "aws_s3_bucket_notification" "event_source" {
  bucket = aws_s3_bucket.event_source.id

  queue {
    id            = "${local.project_name}-var.environment_name"
    queue_arn     = aws_sqs_queue.s3_event_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "${var.environment_name}/"
  }
}

# dlq
locals {
  dlq_name = "${local.project_name}-${var.environment_name}-dlq"
}

resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  message_retention_seconds = 1209600
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

# cloudwatch metric alarm
resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name          = "${local.project_name}-${var.environment_name}-s3-event-dlq"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "receive dead letter queue alarm"
  alarm_actions       = [aws_sns_topic.dlq.arn]

  dimensions = {
    QueueName = local.dlq_name
  }
}

# lambda function
locals {
  function_name = "${local.project_name}-${var.environment_name}-sns-publisher"
}
resource "aws_lambda_function" "sns_publisher" {
  function_name = local.function_name
  image_uri     = var.lambda_function_image_uri
  package_type  = "Image"
  role          = aws_iam_role.sns_publisher.arn
  timeout       = 5


  environment {
    variables = {
      "TOPIC_ARN" = aws_sns_topic.success.arn
      "REGION"    = var.region
    }
  }
}

resource "aws_iam_role_policy" "sns_publisher" {
  name = "${local.function_name}-role-policy"
  role = aws_iam_role.sns_publisher.id
  policy = templatefile(
    "./lambda_sns_publisher_policy.json",
    {
      topic_arn = aws_sns_topic.success.arn
      queue_arn = aws_sqs_queue.s3_event_queue.arn
    }
  )
}

resource "aws_iam_role" "sns_publisher" {
  name               = "${local.function_name}-role"
  assume_role_policy = file("./lambda_assume_role_policy.json")
}

resource "aws_lambda_event_source_mapping" "sns_publisher" {
  event_source_arn = aws_sqs_queue.s3_event_queue.arn
  function_name    = aws_lambda_function.sns_publisher.arn
}
