include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  node_instance_type = "t3.small"
  k8s_version        = "1.29"
}