output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Private subnets: EKS nodes and RDS."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnets: internet-facing load balancers only."
  value       = aws_subnet.public[*].id
}
