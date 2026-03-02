include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/github-actions-role"
}

dependency "ecr" {
  config_path = "../ecr"

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
  github_org           = "yourmesumtin"
  github_repo          = "platform-modernization-lab"
  ecr_repository_arns  = values(dependency.ecr.outputs.repository_arns)
  create_oidc_provider = true
}