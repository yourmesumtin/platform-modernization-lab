include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  vpc_id              = dependency.vpc.outputs.vpc_id
  private_subnet_ids  = dependency.vpc.outputs.private_subnet_ids
  allowed_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]
  instance_class      = "db.t3.micro"
  db_name             = "appdb"
  db_username         = "dbadmin"
  db_password         = get_env("TF_VAR_db_password")
}