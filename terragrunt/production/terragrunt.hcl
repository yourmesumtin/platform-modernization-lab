include "root" {
  path = find_in_parent_folders()
}

inputs = {
  env = "production"
  tags = {
    Project     = "platform-modernization-lab"
    Environment = "production"
    ManagedBy   = "terragrunt"
  }
}