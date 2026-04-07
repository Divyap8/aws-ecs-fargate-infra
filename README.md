# aws-ecs-fargate-infra

AWS CLI scripts to provision the full infrastructure for running a containerised Node.js API on ECS Fargate. Run steps in order — each script exports variables consumed by the next.

## Architecture

```
Internet
    │
    ▼
API Gateway (Regional)
    │  VPC Link
    ▼
Internal ALB         ← private subnets (10.0.11.0/24, 10.0.12.0/24)
    │
    ▼
ECS Fargate Tasks    ← private subnets, sg-ecs (port 3000)
    │
    └── Outbound via NAT Gateway ← public subnet (10.0.1.0/24)
```

**VPC CIDR:** `10.0.0.0/16` | **Region:** `ap-south-1`

| Subnet | CIDR | AZ | Purpose |
|---|---|---|---|
| Public 1 | 10.0.1.0/24 | ap-south-1a | NAT Gateway |
| Public 2 | 10.0.2.0/24 | ap-south-1b | NAT Gateway (spare) |
| Private 1 | 10.0.11.0/24 | ap-south-1a | ALB + ECS tasks |
| Private 2 | 10.0.12.0/24 | ap-south-1b | ALB + ECS tasks |

## Scripts

```
aws-ecs-fargate-infra/
├── scripts/
│   ├── 01-vpc.sh              # VPC, subnets, IGW, NAT Gateway, route tables
│   ├── 02-security-groups.sh  # sg-alb (port 80 from VPC) + sg-ecs (port 3000 from ALB)
│   ├── 03-ecr.sh              # ECR repo, image scanning, lifecycle policy (keep last 10)
│   ├── 04-iam.sh              # ECS Execution Role + Task Role
│   ├── 05-cloudwatch.sh       # Log group /ecs/node-api-prod, 30-day retention
│   ├── 06-alb.sh              # Internal ALB, target group (type=ip), listener port 80
│   ├── 07-ecs.sh              # ECS cluster (Container Insights on), service (desired=2)
│   └── 08-api-gateway.sh      # VPC Link, REST API, /api/{proxy+} → ALB
└── README.md
```

## Usage

```bash
# Set once — all scripts read these
export AWS_REGION=ap-south-1
export PROJECT=node-api
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Run in order
bash scripts/01-vpc.sh
bash scripts/02-security-groups.sh
bash scripts/03-ecr.sh
bash scripts/04-iam.sh
bash scripts/05-cloudwatch.sh
bash scripts/06-alb.sh
bash scripts/07-ecs.sh
bash scripts/08-api-gateway.sh
```

After `08-api-gateway.sh` completes, your API is live at:
```
https://<API_ID>.execute-api.<REGION>.amazonaws.com/prod/api/v1/hello
```

## Prerequisites

- AWS CLI v2 configured (`aws configure`)
- Docker Desktop (for ECR push in `03-ecr.sh`)
- IAM permissions: EC2, ECS, ECR, IAM, ELB, API Gateway, CloudWatch Logs

## Application Repo

App code, Dockerfile, CI/CD pipeline → [`fargate-express-blueprint`](https://github.com/Divyap8/fargate-express-blueprint.git)
