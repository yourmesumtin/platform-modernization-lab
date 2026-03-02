variable "env" {
  type = string
}

variable "github_org" {
  description = "Your GitHub username or org"
  type        = string
}

variable "github_repo" {
  description = "Repository name"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ARNs of ECR repos this role can push to"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}