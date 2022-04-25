##################################################
# Variables
# This file has various groupings of variables
##################################################

##################################################
# AWS
##################################################

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "aws_key_pair_id" {
  type    = string
  default = ""
}

variable "aws_security_group_id" {
  type    = string
  default = ""
}

variable "ami_id" {
  type    = string
  default = ""
}

variable "image_recipe_version" {
  type    = string
  default = "1.0.0"
}

##################################################
# Software Version Variables
##################################################

variable "easybuild_version" {
  type    = string
  default = "4.5.4"
}

variable "pcluster_versions" {
  default = ["3.1.2", "3.2.0b1"]
}

##################################################
# ImageBuilder Variables
##################################################

variable "ec2_iam_role_name" {
  type        = string
  description = "The EC2's IAM role name."
  default     = "svc-image-builder-role"
}

variable "ebs_root_vol_size" {
  type    = number
  default = 35
}


