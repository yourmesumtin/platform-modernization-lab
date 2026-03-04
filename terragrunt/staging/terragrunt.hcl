include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = {
  env = "staging"
  tags = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terragrunt"
  }
}