#!/usr/bin/env bash
# 04-iam.sh — ECS Execution Role and Task Role
set -euo pipefail

: "${PROJECT:?Set PROJECT}"

TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# Execution Role — used by ECS agent to pull images from ECR and write to CloudWatch
aws iam create-role \
  --role-name ecsTaskExecutionRole-${PROJECT} \
  --assume-role-policy-document "$TRUST"
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole-${PROJECT} \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
EXEC_ROLE_ARN=$(aws iam get-role \
  --role-name ecsTaskExecutionRole-${PROJECT} \
  --query 'Role.Arn' --output text)

# Task Role — runtime permissions available inside the container
# Attach additional policies here (e.g. S3, SSM, DynamoDB) as needed
aws iam create-role \
  --role-name ecsTaskRole-${PROJECT} \
  --assume-role-policy-document "$TRUST"
TASK_ROLE_ARN=$(aws iam get-role \
  --role-name ecsTaskRole-${PROJECT} \
  --query 'Role.Arn' --output text)

echo "export EXEC_ROLE_ARN=$EXEC_ROLE_ARN"
echo "export TASK_ROLE_ARN=$TASK_ROLE_ARN"
