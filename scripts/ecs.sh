#!/usr/bin/env bash
# 07-ecs.sh — ECS cluster, task definition, service (desired count 2)
set -euo pipefail

: "${PROJECT:?}" "${AWS_REGION:?}" "${TG_ARN:?}" "${PVT_SUB_1:?}" "${PVT_SUB_2:?}" "${SG_ECS:?}"
: "${EXEC_ROLE_ARN:?}" "${TASK_ROLE_ARN:?}" "${FULL_IMAGE_URI:?Set FULL_IMAGE_URI to your ECR image}"

# Cluster with Container Insights enabled
aws ecs create-cluster \
  --cluster-name ${PROJECT}-cluster \
  --settings name=containerInsights,value=enabled

# Task definition — 256 CPU / 512 MB, awsvpc networking (required for Fargate)
cat > /tmp/task-definition.json << EOF
{
  "family": "${PROJECT}-td",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "${EXEC_ROLE_ARN}",
  "taskRoleArn": "${TASK_ROLE_ARN}",
  "containerDefinitions": [{
    "name": "${PROJECT}-container",
    "image": "${FULL_IMAGE_URI}",
    "essential": true,
    "portMappings": [{"containerPort": 3000, "protocol": "tcp"}],
    "environment": [
      {"name": "PORT", "value": "3000"},
      {"name": "APP_ENV", "value": "production"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${PROJECT}-prod",
        "awslogs-region": "${AWS_REGION}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL","wget -qO- http://localhost:3000/health || exit 1"],
      "interval": 30, "timeout": 5, "retries": 3, "startPeriod": 10
    }
  }]
}
EOF

aws ecs register-task-definition --cli-input-json file:///tmp/task-definition.json

# Service — 2 tasks across 2 AZs, rolling deploy (50% min / 200% max)
aws ecs create-service \
  --cluster ${PROJECT}-cluster \
  --service-name ${PROJECT}-svc \
  --task-definition ${PROJECT}-td \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PVT_SUB_1,$PVT_SUB_2],securityGroups=[$SG_ECS],assignPublicIp=DISABLED}" \
  --load-balancers "[{\"targetGroupArn\":\"$TG_ARN\",\"containerName\":\"${PROJECT}-container\",\"containerPort\":3000}]" \
  --deployment-configuration "minimumHealthyPercent=50,maximumPercent=200"

echo "Waiting for service to stabilise..."
aws ecs wait services-stable \
  --cluster ${PROJECT}-cluster \
  --services ${PROJECT}-svc

echo "ECS service stable: ${PROJECT}-svc"
