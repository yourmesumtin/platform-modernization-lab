# Platform Modernization Lab

A production-grade cloud platform built with Terraform, AWS, Kubernetes, and GitHub Actions — demonstrating the thinking and execution of a principal platform engineer.

---

## What This Project Demonstrates

This is not a tutorial project. Every decision made here reflects real-world platform engineering thinking: what to build, what not to build, when to use existing tooling, and when to write your own. The goal is a fully observable, automated, secure platform that can onboard a new microservice in minutes.

---

## Architecture Overview

```
GitHub (source of truth)
    │
    ▼
GitHub Actions (CI/CD)
    │   OIDC — no static AWS keys
    ▼
AWS
    ├── VPC (10.0.0.0/16)
    │   ├── Public Subnets  (us-east-2a, us-east-2b)
    │   ├── Private Subnets (us-east-2a, us-east-2b)
    │   ├── Internet Gateway
    │   └── NAT Gateway (single — intentional for lab)
    │
    ├── EKS (Kubernetes 1.29)
    │   ├── Managed Node Group (2 nodes, t3.small)
    │   ├── IRSA enabled (IAM Roles for Service Accounts)
    │   └── CloudWatch Container Insights
    │
    ├── ECR
    │   ├── api
    │   ├── worker
    │   └── frontend
    │
    ├── RDS (PostgreSQL 15.x)
    │   ├── Single instance (db.t3.micro)
    │   ├── Private subnet only
    │   └── Encrypted at rest
    │
    └── CloudWatch
        ├── Container Insights (EKS metrics)
        ├── 5 metric alarms
        ├── SNS alerting
        └── Platform dashboard
```

---

## Repository Structure

```
platform-modernization-lab/
│
├── modules/                        # Reusable Terraform modules
│   ├── vpc/                        # VPC, subnets, NAT, routing
│   ├── eks/                        # EKS cluster, node group, IRSA
│   ├── ecr/                        # ECR repositories + lifecycle policies
│   ├── rds/                        # PostgreSQL RDS instance
│   ├── github-actions-role/        # OIDC role for GitHub Actions
│   └── monitoring/                 # CloudWatch alarms + dashboard
│
├── live/                           # Environment-specific configurations
│   ├── staging/
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── production/
│       ├── main.tf
│       ├── backend.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── k8s/                            # Kubernetes manifests
│   ├── deployment.yaml             # App deployment with probes + resource limits
│   ├── hpa.yaml                    # Horizontal Pod Autoscaler
│   └── canary/
│       └── deployment-canary.yaml  # Canary deployment manifest
│
├── .github/workflows/
│   └── deploy.yml                  # Full CI/CD pipeline
│
├── app.py                          # Flask application
├── requirements.txt
└── Dockerfile
```

---

## CI/CD Pipeline

Every push to `main` triggers a fully automated pipeline with a manual approval gate before production.

```
git push → main
    │
    ▼
[1] Terraform Staging
    Apply infrastructure changes to staging
    │
    ▼
[2] Build & Push
    docker build → tag with git SHA → push to ECR
    │
    ▼
[3] Deploy to Staging
    kubectl set image → rollout status → smoke test
    │
    ▼
[4] ⏸ Manual Approval Gate
    GitHub Environment protection — reviewer must approve
    │
    ▼
[5] Terraform Production
    Apply infrastructure changes to production
    │
    ▼
[6] Canary Deploy
    Deploy 1 canary pod (~33% traffic)
    Monitor for 60 seconds
    │
    ├── Healthy → Full rollout → Delete canary
    └── Unhealthy → Auto rollback → Pipeline fails
```

### Key Pipeline Design Decisions

**OIDC authentication** — GitHub Actions assumes an IAM role via OIDC instead of using static `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Short-lived tokens are issued per workflow run. No long-lived credentials stored anywhere.

**Git SHA as image tag** — every Docker image is tagged with the exact commit that built it. Full traceability from a running pod back to the source code.

**`kubectl rollout status`** — the pipeline waits for rollout confirmation before declaring success. A broken deploy fails the pipeline immediately.

**Canary before full rollout** — new production images serve ~33% of traffic for 60 seconds before replacing the stable deployment. Automatic rollback if pods don't reach ready state.

---

## Terraform Module Design

Modules are written from scratch, not sourced from the Terraform Registry. This is an intentional decision: the community VPC module has 600+ lines and supports 50+ variables. This platform needs 2 public subnets, 2 private subnets, and a NAT gateway. Writing it directly means every line is understood and explainable.

### Module principles

**Lean interfaces** — modules expose only what callers need. Outputs are scoped to what consumers actually reference.

**`for_each` over resource duplication** — the ECR module creates all repositories from a single resource block using `for_each = toset(var.repository_names)`. Adding a new service means adding one string to a list.

**Explicit over implicit** — no default values on sensitive variables. Terraform forces the caller to provide them. Passwords never have defaults.

**Comments on conscious decisions** — every lab simplification (single NAT, single-AZ RDS, `skip_final_snapshot`) is annotated with what the production equivalent would be. A reviewer can always understand why.

### Remote State

State is stored in S3 with DynamoDB locking. Each environment has its own state key, preventing cross-environment interference.

```
s3://tf-state-platform-lab/live/staging/terraform.tfstate
s3://tf-state-platform-lab/live/production/terraform.tfstate
```

---

## Kubernetes Configuration

### Deployment

The application deployment includes both readiness and liveness probes — two separate concerns:

- **Readiness** — controls traffic routing. Pod only receives requests when truly ready to serve them.
- **Liveness** — controls pod restart. Kubernetes restarts the pod if it becomes unresponsive.

Resource requests and limits are defined on every container. This is required for HPA to function — without `requests.cpu`, the autoscaler has no baseline to measure against.

### Horizontal Pod Autoscaler

HPA is configured on `autoscaling/v2` (not v1). Scale target is 70% average CPU utilization across pods, with a minimum of 2 replicas and a maximum of 6.

### Canary Strategy

The canary deployment shares the `app: api` label with the stable deployment, meaning the Kubernetes Service routes traffic to both without any additional configuration. With 1 canary pod and 2 stable pods, traffic splits approximately 33/67. No service mesh required for this pattern.

---

## Monitoring

CloudWatch Container Insights is enabled via the `amazon-cloudwatch-observability` EKS add-on. This provides node and pod metrics automatically without manual instrumentation.

### Alarms

| Alarm | Threshold | Why |
|---|---|---|
| Node CPU | > 80% for 2 periods | Sustained high CPU indicates capacity issue |
| Node Memory | > 80% for 2 periods | Memory pressure before OOM kills |
| Pod Restarts | > 5 in 1 minute | Crash loop detection |
| RDS CPU | > 80% for 2 periods | Database under load |
| RDS Free Storage | < 5GB | Silent killer — catches disk exhaustion early |

### Alerting

SNS topic routes alarms to email. In production this would be SNS → PagerDuty or SNS → Slack via Lambda. The pattern is identical — only the SNS subscription endpoint changes.

### Dashboard as Code

The CloudWatch dashboard is defined in Terraform. It is versioned, reproducible, and identical across environments. Clicking together a dashboard in the console is not repeatable and not reviewable.

---

## Security Decisions

**No public database access** — RDS is in private subnets with a security group that only allows port 5432 from the VPC private CIDR blocks. It is never reachable from the internet.

**Encryption at rest** — RDS storage is encrypted. ECR images are scanned on push for vulnerabilities.

**Least privilege on node IAM role** — only three policies attached: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly`. Nothing more.

**IRSA ready** — the OIDC provider is configured on the EKS cluster. Individual pods can assume scoped IAM roles rather than inheriting broad node permissions.

**Sensitive outputs** — RDS endpoint and CA certificate outputs are marked `sensitive = true`. They never print in CI logs.

**No hardcoded credentials** — passwords are injected via `TF_VAR_` environment variables from GitHub secrets. `terraform.tfvars` files are gitignored.

---

## Local Development

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- kubectl
- Docker

### Bootstrap (first time only)

```bash
# Staging
cd live/staging
terraform init
terraform apply

# Connect kubectl
aws eks update-kubeconfig --region us-east-2 --name staging-eks-cluster

# Deploy initial manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/hpa.yaml
```

### Teardown

```bash
cd live/staging
terraform destroy

cd ../production
terraform destroy
```

Always destroy when not actively using the environment. EKS, NAT Gateway, and RDS are the primary cost drivers.

---

## Cost Awareness

Approximate monthly cost if left running 24/7:

| Resource | Cost |
|---|---|
| EKS Cluster | ~$72/month |
| EC2 Nodes (2x t3.small) | ~$30/month |
| NAT Gateway | ~$33/month |
| RDS t3.micro | ~$12/month |
| ECR storage | ~$1/month |
| **Total per environment** | **~$150/month** |

Two environments (staging + production) running continuously would cost approximately $300/month. Use `terraform destroy` when not in use.

---

## What Would Be Different in Production

| Decision | Lab | Production |
|---|---|---|
| NAT Gateway | Single | One per AZ for high availability |
| RDS | Single instance | Multi-AZ with automated failover |
| RDS credentials | tfvars / GitHub secret | AWS Secrets Manager with rotation |
| EKS node size | t3.small | Sized to workload |
| Canary monitoring | 60 second wait | Datadog / Prometheus metrics-based promotion |
| Alerting | SNS → Email | SNS → PagerDuty |
| Image scanning | ECR basic scanning | Snyk or Prisma Cloud |
| Secrets in pods | Environment variables | AWS Secrets Manager + External Secrets Operator |
| Terraform modules | Local | Internal module registry with versioning |

---

## Author

Built by Yomi — Platform Engineer / SRE  
[github.com/yourmesumtin](https://github.com/yourmesumtin)