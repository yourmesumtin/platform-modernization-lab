include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/monitoring"
}

dependency "eks" {
  config_path = "../eks"

    mock_outputs = {
    cluster_name     = "staging-eks-cluster"
    cluster_endpoint = "https://mock.eks.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

inputs = {
  eks_cluster_name       = dependency.eks.outputs.cluster_name
  db_instance_identifier = "staging-postgres"
  alert_email            = get_env("TF_VAR_alert_email", "")
  aws_region             = "us-east-2"
}