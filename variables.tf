variable "region" {
  description = "Region to use for AWS resources"
  type        = string
  default     = "ap-south-1"
}

variable "global_prefix" {
  description = "Prefix to use for AWS resources"
  type        = string
  default     = "msk_inventory_spike"
}

variable "bucket_name" {
  description = "S3 bucket name (does not support underscore, used hyphen)"
  type        = string
  default     = "msk-inventory-spike-bucket"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "vpc_subnets" {
  type        = list(string)
  description = "Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "msk_topic_name" {
  type        = string
  description = "Topic in which lambda producer puts the message"
  default     = "inventory-update"
}

variable "msk_topic_no_of_partitions" {
  type        = string
  description = "No of partitions for the cluster topic"
  default     = "3"
}

variable "msk_topic_replication_factor" {
  type        = string
  description = "Replica factor for the cluster topic"
  default     = "3"
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime for lambda"
  default     = "java21"
}

variable "lambda_handler_method" {
  type        = string
  description = "Handler method for lambda"
  default     = "lambda.InventoryUpdate::handleRequest"
}

variable "lambda_package_type" {
  type        = string
  description = "Package type for lambda"
  default     = "Zip"
}

variable "lambda_package_name" {
  type        = string
  description = "Package name for lambda"
  default     = "InventoryS3FileUpdateLamda-1.0-SNAPSHOT.zip"
}