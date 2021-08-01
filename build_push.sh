#!/bin/sh

set -e

cd "$(dirname "$0")"/lambda

REGION=$1
if [ -z "$1" ]; then
    echo "missing argument error: REGION"
    exit 1
fi

FUNCTION_NAME=terraform-study-s3-sqs-lambda-sns/sns-publisher

set +e
aws ecr create-repository --repository-name ${FUNCTION_NAME}
set -e

sam build
URI=$(aws ecr describe-repositories --repository-name ${FUNCTION_NAME} --query 'repositories[].repositoryUri' | tr -d '[]"\n\ ')
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' | tr -d '[]"\n\ ')

docker tag awscostnotificationfunction:go1.x-v1 "${URI}:1.0.0"

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
docker push "${URI}:1.0.0"
