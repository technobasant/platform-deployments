output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "ecr_repositories" {
  description = "Where CI would push governed-agent's images."
  value       = module.ecr.repository_urls
}

output "database_endpoint" {
  description = "RDS writer endpoint."
  value       = module.rds.endpoint
}

output "app_role_arn" {
  description = "Role the api pods receive through EKS Pod Identity."
  value       = module.eks.app_role_arn
}
