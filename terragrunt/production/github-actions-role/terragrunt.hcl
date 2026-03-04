include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/github-actions-role"
}

inputs = {
  github_org                 = "yourmesumtin"
  github_repo                = "platform-modernization-lab"
  ecr_repository_arns        = []
  create_oidc_provider       = false
  existing_oidc_provider_arn = "arn:aws:iam::579635679563:oidc-provider/token.actions.githubusercontent.com"
}