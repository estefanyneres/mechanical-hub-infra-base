output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = [for s in aws_subnet.private : s.id]
}

output "alb_sg_id" {
  description = "ID do security group do ALB"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID do security group da aplicacao"
  value       = aws_security_group.app.id
}

output "rds_sg_id" {
  description = "ID do security group do RDS"
  value       = aws_security_group.rds.id
}

output "lambda_auth_sg_id" {
  description = "ID do security group da Lambda de autenticacao de clientes"
  value       = aws_security_group.lambda_auth.id
}

output "ecr_url" {
  description = "URL do repositorio ECR"
  value       = aws_ecr_repository.app.repository_url
}

output "microservices_ecr_urls" {
  description = "URLs dos repositorios ECR dos microsservicos"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}
