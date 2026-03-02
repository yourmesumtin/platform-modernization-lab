include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/github-actions-role"
}

dependency "ecr" {
  config_path = "../ecr"
}

inputs = {
  github_org           = "yourmesumtin"
  github_repo          = "platform-modernization-lab"
  ecr_repository_arns  = values(dependency.ecr.outputs.repository_arns)
  create_oidc_provider = true
}