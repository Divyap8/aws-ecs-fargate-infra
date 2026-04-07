#!/usr/bin/env bash
# 03-ecr.sh — ECR repository, image scanning, lifecycle policy
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}" "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
REPO_NAME=${REPO_NAME:-node-api-prod}
ECR_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

aws ecr create-repository \
  --repository-name $REPO_NAME \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability IMMUTABLE

# Keep only last 10 images — prevents unbounded storage costs
aws ecr put-lifecycle-policy \
  --repository-name $REPO_NAME \
  --lifecycle-policy-text '{
    "rules":[{
      "rulePriority":1,
      "description":"Keep last 10",
      "selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":10},
      "action":{"type":"expire"}
    }]
  }'

echo "ECR repo: ${ECR_URI}/${REPO_NAME}"
echo "export ECR_URI=$ECR_URI"
echo "export REPO_NAME=$REPO_NAME"
