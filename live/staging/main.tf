module "vpc" {
  source = "../../modules/vpc"

  env                  = "staging"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                  = ["us-east-2a", "us-east-2b"]

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source = "../../modules/eks"

  env                = "staging"
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = "t3.small"
  k8s_version        = "1.29"

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = ["api", "worker", "frontend"]

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "rds" {
  source = "../../modules/rds"

  env                 = "staging"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  allowed_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]

  instance_class = "db.t3.micro"
  db_name        = "appdb"
  db_username    = "dbadmin"
  db_password    = var.db_password  # injected via tfvars or CI secret

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "github_actions_role" {
  source = "../../modules/github-actions-role"

  env                 = "staging"
  github_org          = "yourmesumtin"
  github_repo         = "platform-modernization-lab"
  ecr_repository_arns = values(module.ecr.repository_arns)
  create_oidc_provider = true    # ← staging owns it

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  env                    = "staging"
  eks_cluster_name       = module.eks.cluster_name
  db_instance_identifier = "${var.env}-postgres"
  alert_email            = var.alert_email

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}