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

dependency "vpc" {
  config_path  = "../vpc"
  skip_outputs = true

  mock_outputs = {
    vpc_id             = "vpc-00000000"
    private_subnet_ids = ["subnet-00000000", "subnet-11111111"]
    public_subnet_ids  = ["subnet-22222222", "subnet-33333333"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
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