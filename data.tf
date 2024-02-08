data "aws_caller_identity" "user_identity" {}

data "aws_availability_zones" "available_azs" {
  state = "available"
}

data "aws_msk_cluster" "kafka_cluster_data" {
  cluster_name = aws_msk_cluster.kafka_cluster.cluster_name
}