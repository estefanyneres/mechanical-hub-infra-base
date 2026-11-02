resource "aws_ecr_repository" "app" {
  name                 = var.projectName
  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = var.projectName
  })
}

locals {
  microservice_ecr_repos = [
    "${var.projectName}-core-service",
    "${var.projectName}-repair-service",
    "${var.projectName}-stock-service",
    "${var.projectName}-billing-service",
  ]
}

resource "aws_ecr_repository" "microservices" {
  for_each = toset(local.microservice_ecr_repos)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = each.value
  })
}
