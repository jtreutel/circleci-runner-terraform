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