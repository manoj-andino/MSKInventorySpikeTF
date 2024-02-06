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
  region = "ap-south-1"
}

resource "aws_vpc" "msk_inventory_spike_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MSK Inventory Spike VPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.vpc_subnets)
  vpc_id = aws_vpc.msk_inventory_spike_vpc.id
  cidr_block = element(var.vpc_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public subnet ${count.index+1}"
  }
}

resource "aws_internet_gateway" "msk_inventory_spike_igw" {
  vpc_id = aws_vpc.msk_inventory_spike_vpc.id

  tags = {
    Name = "MSK Inventory Spike VPC IGW"
  }
}

resource "aws_route_table" "misv_second_route_table" {
  vpc_id = aws_vpc.msk_inventory_spike_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.msk_inventory_spike_igw.id
  }

  tags = {
    Name = "MIS Second route table"
  }
}

resource "aws_route_table_association" "misv_second_route_table_association" {
  count = length(var.vpc_subnets)
  subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.misv_second_route_table.id
}