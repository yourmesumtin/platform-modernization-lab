variable "env" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of 2 public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of 2 private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project     = "platform-modernization-lab"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

variable "db_password" {
  description = "RDS master password — injected via tfvars or CI secret"
  type        = string
  sensitive   = true
}