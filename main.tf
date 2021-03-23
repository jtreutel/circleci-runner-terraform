

resource "aws_security_group" "circleci_runner" {
  name        = "%{if var.resource_prefix != ""}${var.resource_prefix} %{endif}CircleCI Runner SG"
  description = "Allows outbound traffic, optionally allows inbound SSH."
  vpc_id      = var.vpc_id
}
resource "aws_security_group_rule" "allow_inbound_ssh" {
  count             = var.inbound_cidrs != null ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.inbound_cidrs
  security_group_id = aws_security_group.circleci_runner.id
}
resource "aws_security_group_rule" "allow_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = var.outbound_cidrs != null ? var.outbound_cidrs : ["0.0.0.0/0"]
  security_group_id = aws_security_group.circleci_runner.id
}


data "aws_ami" "amazon_linux_2" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}


resource "aws_instance" "circleci_runner" {
  count                       = var.cluster_size
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_size
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = var.assign_public_ip
  vpc_security_group_ids             = [aws_security_group.circleci_runner.id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    tags = merge(
      var.extra_tags,
      {
        Name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-%03d-root", count.index + 1)
      }
    )

  }

  tags = merge(
    var.extra_tags,
    {
      Name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-%03d", count.index + 1)
    }
  )

  lifecycle {
    ignore_changes = [ami] #to avoid undesired create/destroy of instances when a newer AMI is released.
  }
}
