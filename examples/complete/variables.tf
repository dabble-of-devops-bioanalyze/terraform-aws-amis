variable "region" {
  type = string
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
