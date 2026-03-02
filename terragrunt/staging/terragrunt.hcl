include "root" {
  path = find_in_parent_folders()
}

inputs = {
  env = "staging"
  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terragrunt"
  }
}