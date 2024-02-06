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