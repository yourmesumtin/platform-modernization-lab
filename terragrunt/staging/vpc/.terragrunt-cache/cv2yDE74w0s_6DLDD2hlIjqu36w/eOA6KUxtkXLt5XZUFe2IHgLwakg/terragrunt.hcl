include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                  = ["us-east-2a", "us-east-2b"]
}