terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.global_prefix} VPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.vpc_subnets)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.vpc_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.global_prefix} public subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${var.global_prefix} IGW"
  }
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "${var.global_prefix} second RT"
  }
}

resource "aws_route_table_association" "my_route_table_association" {
  count          = length(var.vpc_subnets)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.my_route_table.id
}