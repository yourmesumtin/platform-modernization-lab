include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/github-actions-role"
}

dependency "ecr" {
  config_path = "../ecr"
#   skip_outputs = true

    mock_outputs = {
    repository_arns = {
      api      = "arn:aws:ecr:us-east-2:123456789012:repository/api"
      worker   = "arn:aws:ecr:us-east-2:123456789012:repository/worker"
      frontend = "arn:aws:ecr:us-east-2:123456789012:repository/frontend"
    }
    repository_urls = {
      api      = "123456789012.dkr.ecr.us-east-2.amazonaws.com/api"
      worker   = "123456789012.dkr.ecr.us-east-2.amazonaws.com/worker"
      frontend = "123456789012.dkr.ecr.us-east-2.amazonaws.com/frontend"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init","plan", "validate"]
}

inputs = {
  env                 = "staging"
  github_org           = "yourmesumtin"
  github_repo          = "platform-modernization-lab"
#   ecr_repository_arns  = []
  ecr_repository_arns  = values(dependency.ecr.outputs.repository_arns)
  create_oidc_provider = false
   existing_oidc_provider_arn = "arn:aws:iam::579635679563:oidc-provider/token.actions.githubusercontent.com"
}