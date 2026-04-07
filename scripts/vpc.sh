#!/usr/bin/env bash
# 01-vpc.sh — VPC, subnets, IGW, NAT Gateway, route tables
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}" "${PROJECT:?Set PROJECT}"

# VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=${PROJECT}-vpc
echo "VPC: $VPC_ID"

# Public subnets (NAT Gateway only)
PUB_SUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 --availability-zone ${AWS_REGION}a \
  --query 'Subnet.SubnetId' --output text)
PUB_SUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 --availability-zone ${AWS_REGION}b \
  --query 'Subnet.SubnetId' --output text)

# Private subnets (ALB + ECS tasks)
PVT_SUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.11.0/24 --availability-zone ${AWS_REGION}a \
  --query 'Subnet.SubnetId' --output text)
PVT_SUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.12.0/24 --availability-zone ${AWS_REGION}b \
  --query 'Subnet.SubnetId' --output text)

# Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Public route table
PUB_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUB_RT \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $PUB_SUB_1 --route-table-id $PUB_RT
aws ec2 associate-route-table --subnet-id $PUB_SUB_2 --route-table-id $PUB_RT

# NAT Gateway (private subnets use this to pull from ECR)
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
  --query 'AllocationId' --output text)
NAT_GW=$(aws ec2 create-nat-gateway \
  --subnet-id $PUB_SUB_1 \
  --allocation-id $EIP_ALLOC \
  --query 'NatGateway.NatGatewayId' --output text)
echo "Waiting for NAT Gateway..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW

# Private route table
PVT_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PVT_RT \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW
aws ec2 associate-route-table --subnet-id $PVT_SUB_1 --route-table-id $PVT_RT
aws ec2 associate-route-table --subnet-id $PVT_SUB_2 --route-table-id $PVT_RT

echo "Done. Export these for subsequent scripts:"
echo "export VPC_ID=$VPC_ID"
echo "export PUB_SUB_1=$PUB_SUB_1 PUB_SUB_2=$PUB_SUB_2"
echo "export PVT_SUB_1=$PVT_SUB_1 PVT_SUB_2=$PVT_SUB_2"
