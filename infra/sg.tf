resource "aws_security_group" "alb" {
  name        = "${var.projectName}-alb-sg"
  description = "Security group do Application Load Balancer"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.projectName}-alb-sg"
  })
}

resource "aws_security_group" "app" {
  name        = "${var.projectName}-app-sg"
  description = "Security group da aplicacao (NodePort), recebe trafego somente do ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "NodePort a partir do ALB"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.projectName}-app-sg"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.projectName}-rds-sg"
  description = "Security group do RDS, recebe trafego somente da aplicacao"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "PostgreSQL a partir da aplicacao"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.projectName}-rds-sg"
  })
}
