locals {
  asg_name = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-asg"
}

data "aws_region" "current" {}

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "archive_file" "queue_depth_function" {
  type             = "zip"
  source_file      = "${path.module}/lambda/get_queue_depth.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/lambda/get_queue_depth.zip"
}

data "aws_kms_key" "existing_key" {
  count = var.secrets_manager_kms_key_id != "" ? 1 : 0

  key_id = var.secrets_manager_kms_key_id
}