variable "env" {
  type = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name for ContainerInsights dimensions"
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS instance identifier for alarm dimensions"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive alarm notifications"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}