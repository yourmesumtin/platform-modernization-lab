include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
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
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  node_instance_type = "t3.small"
  k8s_version        = "1.29"
}