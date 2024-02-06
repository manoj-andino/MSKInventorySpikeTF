########################################################################################################################
# VPC and subnets 
########################################################################################################################

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

########################################################################################################################
# Security group
########################################################################################################################
resource "aws_security_group" "kafka_sg" {
  name   = "${var.global_prefix}_kafka_sg"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 0
    to_port     = 9092
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################################################################################################
# Kafka cluster
########################################################################################################################

resource "aws_kms_key" "kafka_kms_key" {
  description = "Key for MSK"
}

resource "aws_cloudwatch_log_group" "kafka_log_group" {
  name = "${var.global_prefix}_msk_logs"
}

resource "aws_msk_configuration" "kafka_cluster_custom_configuration" {
  kafka_versions    = ["3.5.1"]
  name              = "${var.global_prefix}_kafka_config"
  server_properties = <<EOF
    auto.create.topics.enable=false
    default.replication.factor=3
    min.insync.replicas=1
    num.io.threads=8
    num.network.threads=5
    num.partitions=1
    num.replica.fetchers=2
    replica.lag.time.max.ms=30000
    socket.receive.buffer.bytes=102400
    socket.request.max.bytes=104857600
    socket.send.buffer.bytes=102400
    unclean.leader.election.enable=true
    zookeeper.session.timeout.ms=18000
  EOF
}

resource "aws_msk_cluster" "kafka_cluster" {
  cluster_name           = var.global_prefix
  kafka_version          = "3.5.1"
  number_of_broker_nodes = length(data.aws_availability_zones.available_azs.names)

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = [
      aws_subnet.public_subnets[0].id,
      aws_subnet.public_subnets[1].id,
      aws_subnet.public_subnets[2].id
    ]
    security_groups = [aws_security_group.kafka_sg.id]
  }

}