#################################################
# Provider Details & Project Name
#################################################

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true

}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true

}

variable "aws_region" {
  default = "us-east-2"

}

variable "project" {
  default = "Terraform"

}

#################################################
# VPC Requiremnet
#################################################

variable "vpc_cidr" {
  default = "172.16.0.0/16"

}

variable "aws_route_table" {
  description = "Public & Private Route-table"
  default     = "0.0.0.0/0"

}

#################################################
# EC2 Requirement 
#################################################

variable "image_id" {
  default = "ami-04e5276ebb8451442"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "asg_count" {
  default = 3
}
