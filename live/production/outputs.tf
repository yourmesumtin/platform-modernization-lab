output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "github_actions_role_arn" {
  value = module.github_actions_role.role_arn
}

output "rds_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}