output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Security group EKS attaches to the control plane and managed nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "app_role_arn" {
  description = "Role the application's pods receive through Pod Identity."
  value       = aws_iam_role.app.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider for IRSA roles."
  value       = aws_iam_openid_connect_provider.this.arn
}
