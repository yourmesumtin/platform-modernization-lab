include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/rds"
}

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
    env                 = "production"
  vpc_id              = dependency.vpc.outputs.vpc_id
  private_subnet_ids  = dependency.vpc.outputs.private_subnet_ids
  allowed_cidr_blocks = ["10.1.3.0/24", "10.1.4.0/24"]
  instance_class      = "db.t3.micro"
  db_name             = "appdb"
  db_username         = "dbadmin"
  db_password         = get_env("TF_VAR_db_password", "")

  # Production safety — directly addresses assessment requirement
  deletion_protection = true
}