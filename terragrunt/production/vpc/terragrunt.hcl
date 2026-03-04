include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
  azs                  = ["us-east-2a", "us-east-2b"]
}