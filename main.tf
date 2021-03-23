

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



resource "aws_placement_group" "circleci_runner" {
  name     = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-pg"
  strategy = "spread"
}

resource "aws_autoscaling_group" "circleci_runner" {
  name                      = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-asg"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = var.asg_desired_size
  force_delete              = true
  placement_group           = aws_placement_group.circleci_runner.id
  vpc_zone_identifier       = var.subnet_list

  launch_template {
    id      = aws_launch_template.circleci_runner.id
    version = var.launch_template_version
  }


  dynamic "tag" {
    for_each = var.extra_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}







resource "aws_launch_template" "circleci_runner" {
  name = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-lt"

  block_device_mappings {
    device_name = "/dev/xvda" #this is usally the root volume mount point
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = "true"
    }
  }

  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_size
  key_name      = var.key_name != "" ? var.key_name : null
  #vpc_security_group_ids = [aws_security_group.circleci_runner.id]
  network_interfaces {
    associate_public_ip_address = var.assign_public_ip
    security_groups             = [aws_security_group.circleci_runner.id]

  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.extra_tags,
      {
        Name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner")
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.extra_tags,
      {
        Name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner")
      }
    )
  }

  #user_data = filebase64("${path.module}/example.sh")
  user_data = templatefile(
    "${path.module}/userdata/runner_install.sh.tpl",
    {
      runner_name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner")
      auth_token  = var.auth_token,
    }
  )

}