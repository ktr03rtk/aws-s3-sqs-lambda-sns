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

resource "aws_sns_topic" "normal" {
  name = "${var.environment_name}-normal"
}

resource "aws_sns_topic" "dlq" {
  name = "${var.environment_name}-dlq"
}

