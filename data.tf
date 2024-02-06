data "aws_caller_identity" "user_identity" {}

data "aws_availability_zones" "available_azs" {
  state = "available"
}