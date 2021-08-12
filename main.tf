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

module "s3_sqs_lambda_sns" {
  source                    = "./modules/s3_sqs_lambda_sns"
  project_name              = local.project_name
  environment_name          = var.environment_name
  lambda_function_image_uri = var.lambda_function_image_uri
  region                    = var.region
}

