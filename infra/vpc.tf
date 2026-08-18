locals {
  public_subnets = {
    "1a" = { cidr = "10.0.101.0/24", az = "${var.region_default}a" }
    "1b" = { cidr = "10.0.102.0/24", az = "${var.region_default}b" }
  }

  private_subnets = {
    "1a" = { cidr = "10.0.1.0/24", az = "${var.region_default}a" }
    "1b" = { cidr = "10.0.2.0/24", az = "${var.region_default}b" }
  }
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.projectName
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                           = "${var.projectName}-public-${each.key}"
    Tier                                           = "public"
    "kubernetes.io/cluster/eks-${var.projectName}" = "shared"
    "kubernetes.io/role/elb"                       = 1
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name                                           = "${var.projectName}-private-${each.key}"
    Tier                                           = "private"
    "kubernetes.io/cluster/eks-${var.projectName}" = "shared"
    "kubernetes.io/role/internal-elb"              = 1
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.projectName}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.projectName}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
