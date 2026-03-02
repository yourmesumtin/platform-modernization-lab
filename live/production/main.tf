module "vpc" {
  source = "../../modules/vpc"

  env                  = "production"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
  azs                  = ["us-east-2a", "us-east-2b"]

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source = "../../modules/eks"

  env                = "production"
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = "t3.small"
  k8s_version        = "1.29"

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "rds" {
  source = "../../modules/rds"

  env                 = "production"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  allowed_cidr_blocks = ["10.1.3.0/24", "10.1.4.0/24"]

  instance_class = "db.t3.micro"
  db_name        = "appdb"
  db_username    = "dbadmin"
  db_password    = var.db_password

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "github_actions_role" {
  source = "../../modules/github-actions-role"

  env                 = "production"
  github_org          = "yourmesumtin"
  github_repo         = "platform-modernization-lab"
  ecr_repository_arns = []
  create_oidc_provider       = false    # ← staging already owns it
  existing_oidc_provider_arn = "arn:aws:iam::579635679563:oidc-provider/token.actions.githubusercontent.com"

  tags = {
    Project     = "platform-modernization-lab"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}