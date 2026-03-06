include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
    env                 = "staging"
    repository_names = ["api", "worker", "frontend"]
}