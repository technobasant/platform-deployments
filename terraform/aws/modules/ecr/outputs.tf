output "repository_urls" {
  description = "Repository URL by name."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
