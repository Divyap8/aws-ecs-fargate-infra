#!/usr/bin/env bash
# 02-security-groups.sh — ALB and ECS security groups
set -euo pipefail

: "${VPC_ID:?Run 01-vpc.sh first}" "${PROJECT:?Set PROJECT}"

# ALB sg — accepts port 80 from within the VPC (VPC Link source IPs)
SG_ALB=$(aws ec2 create-security-group \
  --group-name sg-alb-${PROJECT} \
  --description "Internal ALB - from VPC Link" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ALB \
  --protocol tcp --port 80 --cidr 10.0.0.0/16

# ECS sg — accepts port 3000 from ALB sg only (no direct internet access)
SG_ECS=$(aws ec2 create-security-group \
  --group-name sg-ecs-${PROJECT} \
  --description "ECS Fargate tasks - from ALB sg only" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ECS \
  --protocol tcp --port 3000 --source-group $SG_ALB

echo "SG_ALB=$SG_ALB  SG_ECS=$SG_ECS"
echo "export SG_ALB=$SG_ALB"
echo "export SG_ECS=$SG_ECS"
