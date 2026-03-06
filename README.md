# Platform Modernization Lab

A production-grade cloud platform built with Terraform, Terragrunt, AWS, Kubernetes, and GitHub Actions — demonstrating the thinking and execution of a principal platform engineer.

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
    ├── VPC (staging: 10.0.0.0/16 | production: 10.1.0.0/16)
    │   ├── Public Subnets  (us-east-2a, us-east-2b)
    │   ├── Private Subnets (us-east-2a, us-east-2b)
    │   ├── Internet Gateway
    │   └── NAT Gateway (single — intentional for lab cost)
    │
    ├── EKS (Kubernetes 1.29)
    │   ├── Managed Node Group (2 nodes, t3.small)
    │   ├── IRSA enabled (IAM Roles for Service Accounts)
    │   └── CloudWatch Container Insights
    │
    ├── ECR (account-scoped — shared across environments)
    │   ├── api
    │   ├── worker
    │   └── frontend
    │
    ├── RDS (PostgreSQL 15.x)
    │   ├── db.t3.micro, single-AZ
    │   ├── Private subnets only
    │   └── Encrypted at rest
    │
    └── CloudWatch
        ├── Container Insights (automatic EKS metrics)
        ├── 5 metric alarms
        ├── SNS email alerting
        └── Platform dashboard (defined as Terraform code)
```

---

## Repository Structure

```
platform-modernization-lab/
│
├── modules/                        # Reusable Terraform modules (written from scratch)
│   ├── vpc/
│   ├── eks/
│   ├── ecr/
│   ├── rds/
│   ├── github-actions-role/
│   └── monitoring/
│
├── terragrunt/                     # Environment configurations
│   ├── root.hcl                    # Root — auto-generates S3 backend for every module
│   ├── staging/
│   │   ├── terragrunt.hcl          # Staging env inputs (env name, tags)
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── ecr/
│   │   ├── rds/
│   │   ├── github-actions-role/
│   │   └── monitoring/
│   └── production/
│       ├── terragrunt.hcl          # Production env inputs
│       ├── vpc/
│       ├── eks/
│       ├── rds/
│       ├── github-actions-role/
│       └── monitoring/
│
├── k8s/
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── service.yaml
│   └── canary/
│       └── deployment-canary.yaml
│
├── .github/workflows/
│   ├── deploy.yml                  # Full CI/CD pipeline
│   └── destroy.yml                 # Manual destroy with confirmation gate
│
├── app.py                          # Flask API
├── requirements.txt
└── Dockerfile
```

---

## Why Modules Were Written From Scratch

The community VPC Terraform module has 600+ lines supporting 50+ variables. This platform needs 2 public subnets, 2 private subnets, and a NAT gateway. Writing modules directly means every line is understood and explainable in a review — which is the entire point of a platform engineering assessment.

---

## Terragrunt Design

### Why Terragrunt

| Problem | Without Terragrunt | With Terragrunt |
|---|---|---|
| Backend config | Copy-paste `backend.tf` per environment | Single `root.hcl` generates it for every module |
| Module output wiring | Manual variable passing | `dependency` blocks wire outputs declaratively |
| Environment drift | Two `main.tf` files that diverge | DRY — environments inherit from root, only override inputs |
| Apply ordering | Manual | `run-all` respects dependency graph automatically |

### Root Config Pattern

`terragrunt/root.hcl` generates the S3 backend for every module using `path_relative_to_include()`:

```hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "tf-state-platform-lab"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

This generates unique state paths automatically:
- `staging/vpc/terraform.tfstate`
- `staging/eks/terraform.tfstate`
- `production/vpc/terraform.tfstate`

No `backend.tf` files anywhere in the repo.

### Dependency Pattern

```hcl
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000"
    private_subnet_ids = ["subnet-00000000", "subnet-11111111"]
    public_subnet_ids  = ["subnet-22222222", "subnet-33333333"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
```

`mock_outputs` allow `plan` and `validate` to run in CI before the VPC has been applied. Real values are used during `apply`.

### Production Safety — Three Layers

```hcl
# Layer 1 — module input
inputs = {
  deletion_protection = true
}

# Layer 2 — module resource lifecycle
resource "aws_db_instance" "main" {
  lifecycle {
    prevent_destroy = true
  }
}

# Layer 3 — GitHub Environment approval gate (pipeline blocks on reviewer approval)
```

---

## CI/CD Pipeline

```
git push → main
    │
    ▼
[1] Terragrunt Staging
    terragrunt run-all apply
    Applies in dependency order: vpc → eks/ecr/rds → monitoring
    │
    ▼
[2] Build & Push
    docker build
    tag: ECR_URI:GIT_SHA  ← full traceability from pod to commit
    docker push to ECR
    │
    ▼
[3] Deploy to Staging
    kubectl set image deployment/api api=ECR_URI:GIT_SHA
    kubectl rollout status deployment/api --timeout=180s
    echo "Smoke test passed"
    │
    ▼
[4] ⏸  Manual Approval Gate
    GitHub Environment protection rules
    Required reviewer must approve before production
    │
    ▼
[5] Terragrunt Production
    terragrunt run-all apply
    │
    ▼
[6] Canary Deploy to Production
    Deploy 1 canary pod (api-canary)
    Service routes ~33% traffic naturally via shared app:api label
    Monitor 60 seconds
    │
    ├── readyReplicas >= 1 → Full rollout → Delete canary → Done
    └── readyReplicas = 0 → kubectl delete canary → exit 1 → Pipeline fails
```

### OIDC Authentication

No static credentials anywhere. GitHub Actions authenticates to AWS via OIDC — short-lived tokens issued per workflow run. If someone forks the repo they get nothing.

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-2
```

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | Staging GitHub Actions IAM role ARN |
| `DB_PASSWORD` | Staging RDS password |
| `PROD_AWS_ROLE_ARN` | Production GitHub Actions IAM role ARN |
| `PROD_DB_PASSWORD` | Production RDS password |
| `ALERT_EMAIL` | CloudWatch alarm notification email |

---

## Bootstrap (First Time Only)

The pipeline requires the GitHub Actions IAM role to authenticate. That role must be created before the pipeline can run — a one-time chicken-and-egg problem solved by local bootstrap.

```bash
# 1. Create GitHub OIDC provider (one time, account-level)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Apply modules in dependency order
cd terragrunt/staging/vpc && terragrunt apply
cd ../ecr && terragrunt apply
cd ../eks && terragrunt apply
cd ../rds && terragrunt apply
cd ../github-actions-role && terragrunt apply
cd ../monitoring && terragrunt apply

# 3. Enable API_AND_CONFIG_MAP authentication on EKS
aws eks update-cluster-config \
  --name staging-eks-cluster \
  --region us-east-2 \
  --access-config authenticationMode=API_AND_CONFIG_MAP

# 4. Grant your IAM user kubectl access
aws eks create-access-entry \
  --cluster-name staging-eks-cluster \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/YOUR_USER \
  --region us-east-2

aws eks associate-access-policy \
  --cluster-name staging-eks-cluster \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/YOUR_USER \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-2

# 5. Grant GitHub Actions role kubectl access
aws eks create-access-entry \
  --cluster-name staging-eks-cluster \
  --principal-arn arn:aws:iam::ACCOUNT_ID:role/staging-github-actions-role \
  --region us-east-2

aws eks associate-access-policy \
  --cluster-name staging-eks-cluster \
  --principal-arn arn:aws:iam::ACCOUNT_ID:role/staging-github-actions-role \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-2

# 6. Apply Kubernetes manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/service.yaml

# 7. Push — pipeline takes over from here
git push origin main
```

After bootstrap, every change goes through the pipeline. No more local applies.

---

## Monitoring

| Alarm | Threshold | Why |
|---|---|---|
| Node CPU | > 80% for 2 periods | Sustained pressure indicates capacity issue |
| Node Memory | > 80% for 2 periods | Memory pressure before OOM kills pods |
| Pod Restarts | > 5 per minute | Crash loop detection |
| RDS CPU | > 80% for 2 periods | Database under sustained load |
| RDS Free Storage | < 5GB | Silent killer — disk full doesn't appear in CPU metrics |

---

## Kubernetes Configuration

### Probes

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
```

Readiness controls traffic routing. Liveness controls pod restart. Two different concerns — both required.

### HPA

```yaml
apiVersion: autoscaling/v2
spec:
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

HPA requires `resources.requests.cpu` to be defined on the container — otherwise it has nothing to measure utilization against.

### Canary Strategy

The canary deployment shares the `app: api` label with the stable deployment. The Kubernetes Service selects on `app: api` only — it has no awareness of the `track: canary` label. Traffic naturally splits based on pod count: 1 canary pod + 2 stable pods = ~33% canary traffic. No service mesh required.

---

## Destroy

```bash
# Via GitHub Actions (recommended)
# Actions → Terraform Destroy → Run workflow
# Select environment, type DESTROY, approve

# Or locally — production first, then staging
# Production first because staging owns the shared OIDC provider
cd terragrunt/production && terragrunt run-all destroy
cd ../staging && terragrunt run-all destroy
```

Before destroy — delete Kubernetes LoadBalancer services first or the VPC will fail to delete due to orphaned ELB ENIs:
```bash
kubectl delete service api
# Wait 2 minutes, then destroy
```

---

## Cost

Approximate per environment running 24/7:

| Resource | Monthly |
|---|---|
| EKS cluster | ~$72 |
| EC2 nodes (2x t3.small) | ~$30 |
| NAT Gateway | ~$33 |
| RDS db.t3.micro | ~$12 |
| **Total** | **~$150** |

Destroy when not actively working. Two environments = ~$300/month if left running.

---

## Troubleshooting & Learnings

Everything below was encountered and resolved during this build. This is not documentation written after the fact — these are real issues and their real fixes.

---

### AWS Credentials Invalid

**Error:** `InvalidClientTokenId: The security token included in the request is invalid`

**Cause:** Credentials file corrupted or expired.

**Fix:**
```bash
rm ~/.aws/credentials
aws configure
aws sts get-caller-identity  # Always verify before terraform
```

**Learning:** Run `aws sts get-caller-identity` before any Terraform operation. It confirms identity and connectivity in one command.

---

### Terraform State Lock — Stale DynamoDB Entry

**Error:** `Error acquiring the state lock — ConditionalCheckFailedException`

**Cause:** Previous pipeline run was interrupted mid-apply, leaving a lock in DynamoDB that was never released.

**Fix:**
```bash
terraform force-unlock LOCK_ID
# Lock ID is shown in the error output
```

**Learning:** Verify no other apply is actually running before force-unlocking. This is safe when the pipeline was cancelled or timed out, not when another apply is genuinely in progress.

---

### EKS Node Group — Instance Type Not Eligible

**Error:** `AsgInstanceLaunchFailures: The specified instance type is not eligible for Free Tier`

**Fix:** Change `node_instance_type` from `t3.medium` to `t3.small`.

**Learning:** Check Free Tier eligibility before choosing instance types for lab environments. `t3.small` is sufficient for lightweight EKS workloads.

---

### RDS — Reserved Username

**Error:** `MasterUsername admin cannot be used as it is a reserved word`

**Fix:** Change `db_username` from `admin` to `dbadmin`.

**Learning:** PostgreSQL reserves `admin`, `postgres`, `root`, and others. Use `dbadmin` or `appuser`.

---

### RDS — Engine Version Not Available

**Error:** `Cannot find version 15.4 for postgres`

**Fix:**
```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query "DBEngineVersions[].EngineVersion" \
  --output table
```

Use an available version from the output.

**Learning:** AWS periodically removes older minor versions. Never hardcode specific minor versions — check availability first.

---

### kubectl — Credentials Error After Cluster Recreation

**Error:** `error: You must be logged in to the server`

**Cause:** Kubeconfig references the old cluster's certificate authority. The new cluster has a different CA even if the name is the same.

**Fix:**
```bash
kubectl config delete-context arn:aws:eks:REGION:ACCOUNT:cluster/CLUSTER_NAME
aws eks update-kubeconfig --region REGION --name CLUSTER_NAME
```

**Learning:** Always refresh kubeconfig after cluster recreation. The ARN may be identical but the CA certificate is different.

---

### IAM User Cannot Access EKS

**Error:** `You must be logged in to the server` even with valid AWS credentials.

**Cause:** EKS has two separate access control layers — IAM for AWS API calls and Kubernetes RBAC for kubectl. IAM permissions do not automatically grant kubectl access.

**Fix:**
```bash
# Enable API_AND_CONFIG_MAP mode (required for access entries)
aws eks update-cluster-config \
  --name CLUSTER_NAME \
  --region REGION \
  --access-config authenticationMode=API_AND_CONFIG_MAP

# Create access entry
aws eks create-access-entry \
  --cluster-name CLUSTER_NAME \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/USERNAME \
  --region REGION

# Associate cluster admin policy
aws eks associate-access-policy \
  --cluster-name CLUSTER_NAME \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/USERNAME \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region REGION
```

Requires AWS CLI v2.13+. Check version with `aws --version`. Update at https://awscli.amazonaws.com/AWSCLIV2.msi if needed.

**Learning:** EKS authentication is separate from IAM. Access Entries (API mode) is the modern approach — prefer it over the legacy `aws-auth` ConfigMap.

---

### Orphaned Load Balancer Blocks VPC Destroy

**Error:** `DependencyViolation: The subnet has dependencies and cannot be deleted`

**Cause:** A Kubernetes `LoadBalancer` service provisioned an AWS ELB. Terraform doesn't manage this ELB — it was created by the Kubernetes cloud controller. The ELB holds ENIs in the subnets, blocking deletion.

**Fix:**
```bash
# Delete the k8s service first
kubectl delete service api

# Wait 2 minutes for ELB to fully release
# Then delete the orphaned security group
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=VPC_ID" \
  --query "SecurityGroups[].{ID:GroupId,Name:GroupName}"

aws ec2 delete-security-group --group-id sg-XXXXXXXX

# Re-run destroy
terraform destroy
```

**Learning:** Any Kubernetes resource that creates AWS resources must be deleted before `terraform destroy`. Always delete LoadBalancer services and PersistentVolumeClaims before destroying infrastructure.

---

### ECR Repositories Block Destroy

**Error:** `RepositoryNotEmptyException: The repository cannot be deleted because it still contains images`

**Immediate fix:**
```bash
aws ecr delete-repository --repository-name api --force
aws ecr delete-repository --repository-name worker --force
aws ecr delete-repository --repository-name frontend --force
```

**Permanent fix — add to ECR module:**
```hcl
resource "aws_ecr_repository" "main" {
  force_delete = true
  ...
}
```

**Learning:** `force_delete = true` is essential for lab environments. Without it every destroy requires manually emptying repositories first.

---

### ECR Is Account-Scoped, Not Environment-Scoped

**Error:** `RepositoryAlreadyExistsException` when production Terraform tried to create ECR repositories.

**Cause:** ECR repositories are global within an AWS account. Staging already created `api`, `worker`, `frontend`. Production cannot create them again.

**Fix:** Remove ECR module from production entirely. Only staging creates and owns ECR repos. Production references the same repository URLs.

**Learning:** Not all AWS resources are environment-scoped. ECR, IAM OIDC providers, and Route53 hosted zones are account-level. Always check scope before duplicating across environments.

---

### Terragrunt Root Config Not Generating Backend

**Symptom:** No `backend.tf` generated in `.terragrunt-cache`. State saving locally, not to S3.

**Cause:** `find_in_parent_folders()` searches upward for a file named `terragrunt.hcl`. The staging-level `terragrunt.hcl` was intercepting the search before reaching the actual root config.

**Fix:** Rename root config to `root.hcl`:
```bash
mv terragrunt/terragrunt.hcl terragrunt/root.hcl
```

Update all child module includes:
```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

Batch update all files:
```bash
find terragrunt -name "terragrunt.hcl" \
  -exec sed -i 's/find_in_parent_folders()/find_in_parent_folders("root.hcl")/g' {} \;
```

**Learning:** In multi-level Terragrunt structures, use a distinct filename for the root config. `root.hcl` is the community convention for this reason.

---

### Terragrunt Circular Include Error

**Error:** `Only one level of includes is allowed`

**Cause:** The staging `terragrunt.hcl` included the root, and child modules also included the staging file — creating a two-level include chain.

**Fix:** The staging/production env-level `terragrunt.hcl` files should not include the root themselves. Child modules include root directly. Env-level files only contain inputs.

**Learning:** Terragrunt allows only one level of `include`. Each module should include the root directly. Environment-level configs hold shared inputs but are not in the include chain themselves.

---

### Terragrunt Dependency Blocks Block Import

**Error:** `dependency vpc detected no outputs` when running `terragrunt import` before VPC existed.

**Fix — temporary for import operations:**
```hcl
dependency "vpc" {
  config_path  = "../vpc"
  skip_outputs = true

  mock_outputs = {
    vpc_id             = "vpc-00000000"
    private_subnet_ids = ["subnet-00000000", "subnet-11111111"]
  }
}

inputs = {
  # Temporarily hardcode during import
  vpc_id             = "vpc-00000000"
  private_subnet_ids = ["subnet-00000000", "subnet-11111111"]
}
```

Remove `skip_outputs = true` and restore real `dependency.vpc.outputs.*` after import.

**Learning:** `skip_outputs = true` bypasses all dependency output resolution. It enables import before dependencies exist but will silently use mock values during apply if left in place. Always remove it after import.

---

### Terragrunt Mock Outputs Must Allow `init`

**Error:** CI pipeline failed during `terragrunt run-all init` with dependency output errors.

**Cause:** `init` resolves dependency outputs to configure backends. If dependencies have no state, init fails unless mock outputs explicitly permit it.

**Fix:**
```hcl
mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
```

**Learning:** Always include `"init"` in `mock_outputs_allowed_terraform_commands` for CI pipelines. Without it, `run-all init` fails on any module with unresolved dependencies.

---

### OIDC Provider Already Exists on Re-Bootstrap

**Error:** `EntityAlreadyExists: Provider with url https://token.actions.githubusercontent.com already exists`

**Cause:** The OIDC provider is account-scoped. It survives `terraform destroy` because it was outside the destroyed state.

**Fix:** Import it into the new state:
```bash
terragrunt import 'aws_iam_openid_connect_provider.github[0]' \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

**Learning:** The GitHub OIDC provider should be treated as a permanent account-level resource — created once, never destroyed. In production, manage it in a dedicated bootstrap stack separate from environment infrastructure.

---

### Smoke Test Times Out on Terminating Pods

**Error:** `kubectl wait` timed out — matched old pods being terminated alongside new ones.

**Fix:** Replace `kubectl wait` with `kubectl rollout status`:
```yaml
- name: Smoke test
  run: |
    kubectl rollout status deployment/api --timeout=180s
    echo "Smoke test passed"
```

**Learning:** `kubectl rollout status` watches only the new ReplicaSet. It ignores terminating pods from the previous deployment and returns success only when the new version reaches desired state. It is the correct tool for CI deployment verification.

---

### Canary Job — Empty ECR_REGISTRY and IMAGE_TAG

**Error:** `sed` produced an invalid image name — `ECR_REGISTRY` and `IMAGE_TAG` were empty strings.

**Cause:** The canary job listed `needs: [terraform-production]` but not `needs: [build]`. GitHub Actions job outputs are only accessible from jobs directly listed in `needs` — transitive dependencies do not propagate outputs.

**Fix:**
```yaml
deploy-production-canary:
  needs: [build, terraform-production]  # build must be explicit
```

**Learning:** Always explicitly list every job whose outputs you need in `needs`. GitHub Actions does not propagate outputs through intermediate jobs.

---

### Canary Manifest Not Found in Pipeline

**Error:** `sed: can't read k8s/canary/deployment-canary.yaml: No such file or directory`

**Cause:** The file existed locally but in the wrong path (`k8s/deployment-canary.yaml` instead of `k8s/canary/deployment-canary.yaml`) and had not been committed to git.

**Fix:**
```bash
mkdir k8s/canary
mv k8s/deployment-canary.yaml k8s/canary/deployment-canary.yaml
git add k8s/canary/deployment-canary.yaml
git commit -m "move canary manifest to correct path"
git push origin main
```

**Learning:** The pipeline checks out code from git — not your local filesystem. Files must be committed and pushed to be available in the runner. Always verify with `git status` before pushing.

---

### RDS Subnet Group Cannot Move Between VPCs

**Error:** `InvalidParameterValue: The new Subnets are not in the same Vpc as the existing subnet group`

**Cause:** A new VPC was created with different subnets. The existing RDS subnet group was in the old VPC. Subnet groups cannot be moved between VPCs — they must be recreated.

**Fix:**
```bash
# Delete RDS instance first
aws rds delete-db-instance \
  --db-instance-identifier staging-postgres \
  --skip-final-snapshot \
  --region us-east-2

aws rds wait db-instance-deleted \
  --db-instance-identifier staging-postgres \
  --region us-east-2

# Delete subnet group
aws rds delete-db-subnet-group \
  --db-subnet-group-name staging-rds-subnet-group \
  --region us-east-2

# Remove from state and recreate
terragrunt state rm aws_db_subnet_group.main
terragrunt state rm aws_db_instance.main
terragrunt apply
```

**Learning:** RDS subnet groups are VPC-bound. Recreating a VPC requires recreating the RDS subnet group and instance. This is a destructive operation — in production, plan VPC CIDR blocks carefully before deploying any databases.

---

## Production vs Lab Tradeoffs

| Decision | Lab | Production |
|---|---|---|
| NAT Gateway | Single (cost) | One per AZ (HA) |
| RDS | Single instance | Multi-AZ with automated failover |
| RDS credentials | GitHub secret | AWS Secrets Manager with auto-rotation |
| EKS auth mode | API_AND_CONFIG_MAP | API only (more secure) |
| Canary monitoring | 60s pod readiness wait | Prometheus/Datadog error rate + latency |
| Alerting | SNS → Email | SNS → PagerDuty + Slack |
| Terraform modules | Local source | Internal registry with semantic versioning |
| Bootstrap | Manual local apply | Dedicated bootstrap pipeline with approval |
| ECR scope | Shared account-level | Separate AWS account per environment |
| Node size | t3.small | Sized to actual workload with Karpenter |

---

## Author

Built by Yomi — Platform Engineer / SRE
