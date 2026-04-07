#!/usr/bin/env bash
# 08-api-gateway.sh — VPC Link, REST API, /api/{proxy+} catch-all → internal ALB
set -euo pipefail

: "${ALB_ARN:?}" "${ALB_DNS:?}" "${PROJECT:?}" "${AWS_REGION:?}"

# VPC Link — tunnels API Gateway requests to the internal ALB
VPC_LINK_ID=$(aws apigateway create-vpc-link \
  --name ${PROJECT}-vpclink \
  --target-arns $ALB_ARN \
  --query 'id' --output text)

echo "Waiting for VPC Link to become AVAILABLE (~2 min)..."
while true; do
  STATUS=$(aws apigateway get-vpc-link \
    --vpc-link-id $VPC_LINK_ID \
    --query 'status' --output text)
  echo "  Status: $STATUS"
  [ "$STATUS" = "AVAILABLE" ] && break
  sleep 30
done

# REST API
API_ID=$(aws apigateway create-rest-api \
  --name ${PROJECT}-api \
  --endpoint-configuration types=REGIONAL \
  --query 'id' --output text)

ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --query 'items[?path==`/`].id' --output text)

# /api resource
API_RES=$(aws apigateway create-resource \
  --rest-api-id $API_ID --parent-id $ROOT_ID \
  --path-part 'api' --query 'id' --output text)

# /api/{proxy+} — catch-all forwards everything to ALB
PROXY_RES=$(aws apigateway create-resource \
  --rest-api-id $API_ID --parent-id $API_RES \
  --path-part '{proxy+}' --query 'id' --output text)

aws apigateway put-method \
  --rest-api-id $API_ID --resource-id $PROXY_RES \
  --http-method ANY --authorization-type NONE \
  --request-parameters 'method.request.path.proxy=true'

# HTTP_PROXY integration via VPC Link
aws apigateway put-integration \
  --rest-api-id $API_ID --resource-id $PROXY_RES \
  --http-method ANY \
  --type HTTP_PROXY --integration-http-method ANY \
  --uri http://${ALB_DNS}/{proxy} \
  --connection-type VPC_LINK --connection-id $VPC_LINK_ID \
  --request-parameters 'integration.request.path.proxy=method.request.path.proxy'

aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod

echo ""
echo "✅ Deployment complete"
echo "API URL: https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/api/v1/hello"
echo ""
echo "Test:"
echo "  curl https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/api/v1/hello"
