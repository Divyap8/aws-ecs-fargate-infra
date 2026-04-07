#!/usr/bin/env bash
# 06-alb.sh — Internal ALB, target group (type=ip for Fargate), listener
set -euo pipefail

: "${VPC_ID:?}" "${PVT_SUB_1:?}" "${PVT_SUB_2:?}" "${SG_ALB:?}" "${PROJECT:?}"

# Internal ALB — placed in PRIVATE subnets, not internet-facing
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name ${PROJECT}-alb \
  --subnets $PVT_SUB_1 $PVT_SUB_2 \
  --security-groups $SG_ALB \
  --scheme internal \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' --output text)

# Target group — type MUST be ip for Fargate (not instance)
TG_ARN=$(aws elbv2 create-target-group \
  --name ${PROJECT}-tg \
  --protocol HTTP --port 3000 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

# Listener on port 80
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

echo "Internal ALB DNS: $ALB_DNS"
echo "export ALB_ARN=$ALB_ARN"
echo "export ALB_DNS=$ALB_DNS"
echo "export TG_ARN=$TG_ARN"
