########################################################################################################################
# VPC and subnets 
########################################################################################################################
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block

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
# Kafka Security group
########################################################################################################################
resource "aws_security_group" "kafka_sg" {
  name        = "${var.global_prefix}_kafka_sg"
  description = "Security group for MSK"
  vpc_id      = aws_vpc.my_vpc.id
  tags = {
    Name = "${var.global_prefix}_kafka_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "kafka_sg_ingress_rule" {
  security_group_id = aws_security_group.kafka_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "kafka_sg_egress_rule" {
  security_group_id = aws_security_group.kafka_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
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

# resource "aws_msk_configuration" "kafka_cluster_custom_configuration" {
#   kafka_versions    = ["3.5.1"]
#   name              = "${var.global_prefix}_kafka_config"
#   server_properties = <<PROPERTIES
# auto.create.topics.enable=false
# default.replication.factor=3
# min.insync.replicas=2
# num.io.threads=8
# num.network.threads=5
# num.partitions=1
# num.replica.fetchers=2
# replica.lag.time.max.ms=30000
# socket.receive.buffer.bytes=102400
# socket.request.max.bytes=104857600
# socket.send.buffer.bytes=102400
# unclean.leader.election.enable=true
# zookeeper.session.timeout.ms=18000
# PROPERTIES
# }

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

    connectivity_info {
      public_access {
        type = "DISABLED" //Update after creation DISABLED -> SERVICE_PROVIDED_EIPS
      }
    }

    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }

    security_groups = [aws_security_group.kafka_sg.id]
  }

  # configuration_info {
  #   arn      = aws_msk_configuration.kafka_cluster_custom_configuration.arn
  #   revision = aws_msk_configuration.kafka_cluster_custom_configuration.latest_revision
  # }

  client_authentication {
    sasl {
      iam = true
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
    encryption_at_rest_kms_key_arn = aws_kms_key.kafka_kms_key.arn
  }
}

########################################################################################################################
# S3 Bucket
########################################################################################################################
resource "aws_s3_bucket" "my_s3_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "my_s3_bucket_versioning" {
  bucket = aws_s3_bucket.my_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "s3_lambda_notification" {
  bucket = aws_s3_bucket.my_s3_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.my_lambda_function.arn
    events = [
      "s3:ObjectCreated:*"
    ]
  }

  depends_on = [aws_lambda_permission.allow_s3_bucket]
}
########################################################################################################################
# Lambda function
########################################################################################################################
resource "aws_iam_role" "lambda_iam_role" {
  name = "${var.global_prefix}_lambda_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name        = "${var.global_prefix}_lambda_iam_policy"
  description = "IAM policy for lambda"
  path        = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:CreateNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:Describe*",
          "s3-object-lambda:Get*",
          "s3-object-lambda:List*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_iam_role_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_lambda_function" "my_lambda_function" {
  depends_on = [
    aws_iam_role_policy_attachment.lambda_iam_role_policy_attachment,
    aws_msk_cluster.kafka_cluster,
    aws_subnet.public_subnets
  ]
  filename         = "${path.module}/lambda_code/${var.lambda_package_name}"
  source_code_hash = filebase64sha256("${path.module}/lambda_code/${var.lambda_package_name}")
  function_name    = "${var.global_prefix}_lambda_function"
  role             = aws_iam_role.lambda_iam_role.arn

  environment {
    variables = {
      MSK_BOOTSTRAP_SERVERS = data.aws_msk_cluster.kafka_cluster_data.bootstrap_brokers
      TOPIC_NAME            = var.msk_topic_name
      NUM_OF_PARTITIONS     = var.msk_topic_no_of_partitions
      REPLICATION_FACTOR    = var.msk_topic_replication_factor
    }
  }

  runtime      = var.lambda_runtime
  handler      = var.lambda_handler_method
  package_type = var.lambda_package_type
  timeout      = 60
  vpc_config {
    security_group_ids = [aws_security_group.kafka_sg.id]
    subnet_ids         = aws_subnet.public_subnets.*.id
  }
}

resource "aws_lambda_permission" "allow_s3_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.my_s3_bucket.arn
}

resource "aws_vpc_endpoint" "my_s3_vpc_endpoint" {
  vpc_id       = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.ap-south-1.s3"
}

resource "aws_vpc_endpoint_route_table_association" "my_vpce_route_table_association" {
  route_table_id  = aws_route_table.my_route_table.id
  vpc_endpoint_id = aws_vpc_endpoint.my_s3_vpc_endpoint.id
}

resource "aws_key_pair" "ec2_key" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}

resource "aws_instance" "msk_client_ec2" {
  subnet_id                   = aws_subnet.public_subnets[0].id
  ami                         = "ami-0449c34f967dbf18a"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ec2_key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.kafka_sg.id]
  tags = {
    Name = "msk_client_ec2"
  }
}
########################################################################################################################
# Dynamo DB
########################################################################################################################
resource "aws_dynamodb_table" "my_inventory_table_dynamodb" {
  hash_key     = "product_id"
  name         = "inventory"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "product_id"
    type = "S"
  }
}