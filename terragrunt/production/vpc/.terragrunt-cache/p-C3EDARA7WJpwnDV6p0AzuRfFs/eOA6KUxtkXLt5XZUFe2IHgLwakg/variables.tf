variable "env" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of 2 public subnet CIDRs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of 2 private subnet CIDRs"
  type        = list(string)
}

variable "azs" {
  description = "List of 2 availability zones"
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}