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

resource "aws_security_group" "lambda_auth" {
  name        = "${var.projectName}-lambda-auth-sg"
  description = "Security group da Lambda de autenticacao de clientes"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.projectName}-lambda-auth-sg"
  })
}

resource "aws_security_group_rule" "lambda_auth_to_rds" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_auth.id
  source_security_group_id = aws_security_group.rds.id
  description              = "PostgreSQL para o RDS"
}

resource "aws_security_group" "rds" {
  name        = "${var.projectName}-rds-sg"
  description = "Security group do RDS, recebe trafego somente da aplicacao e da Lambda de autenticacao"
  vpc_id      = aws_vpc.vpc.id

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

resource "aws_security_group_rule" "app_from_alb_core_service" {
  type                     = "ingress"
  from_port                = 30081
  to_port                  = 30081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "NodePort do core-service a partir do ALB"
}

resource "aws_security_group_rule" "app_from_alb_repair_service" {
  type                     = "ingress"
  from_port                = 30082
  to_port                  = 30082
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "NodePort do repair-service a partir do ALB"
}

resource "aws_security_group_rule" "app_from_alb_stock_service" {
  type                     = "ingress"
  from_port                = 30083
  to_port                  = 30083
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "NodePort do stock-service a partir do ALB"
}

resource "aws_security_group_rule" "app_from_alb_billing_service" {
  type                     = "ingress"
  from_port                = 30084
  to_port                  = 30084
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "NodePort do billing-service a partir do ALB"
}

resource "aws_security_group_rule" "app_from_alb_sonarqube" {
  type                     = "ingress"
  from_port                = 30900
  to_port                  = 30900
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "NodePort do SonarQube a partir do ALB"
}

resource "aws_security_group_rule" "rds_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.app.id
  description              = "PostgreSQL a partir da aplicacao"
}

resource "aws_security_group_rule" "rds_from_lambda_auth" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda_auth.id
  description              = "PostgreSQL a partir da Lambda de autenticacao"
}
