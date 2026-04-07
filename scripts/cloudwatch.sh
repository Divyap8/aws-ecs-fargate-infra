#!/usr/bin/env bash
# 05-cloudwatch.sh — Log group with 30-day retention
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}" "${PROJECT:?Set PROJECT}"

aws logs create-log-group \
  --log-group-name /ecs/${PROJECT}-prod \
  --region $AWS_REGION

# Never leave log groups with infinite retention
aws logs put-retention-policy \
  --log-group-name /ecs/${PROJECT}-prod \
  --retention-in-days 30

echo "Log group: /ecs/${PROJECT}-prod (30-day retention)"
