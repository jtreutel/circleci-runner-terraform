#-------------------------------------------------------------------------------
# NETWORKING & SECURITY
# Security groups and rules
#-------------------------------------------------------------------------------

resource "aws_security_group" "circleci_runner" {
  name        = "%{if var.resource_prefix != ""}${var.resource_prefix} %{endif}CircleCI Runner SG"
  description = "Allows outbound traffic, optionally allows inbound SSH."
  vpc_id      = var.vpc_id

  tags = var.extra_tags
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



#-------------------------------------------------------------------------------
# CIRCLECI RUNNER CLUSTER
# EC2 Auto Scaling group and launch template with "spread" placement strategy
#-------------------------------------------------------------------------------


resource "aws_placement_group" "circleci_runner" {
  name     = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-pg"
  strategy = "spread"

  tags = var.extra_tags
}

resource "aws_autoscaling_group" "circleci_runner" {
  name                      = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-asg"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  health_check_grace_period = 300
  health_check_type         = "EC2"
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

  ebs_optimized = true
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_size
  key_name      = var.key_name != "" ? var.key_name : null
  network_interfaces {
    associate_public_ip_address = var.assign_public_ip
    security_groups             = [aws_security_group.circleci_runner.id]
  }
  user_data = base64encode(
    templatefile(
      "${path.module}/userdata/runner_install.sh.tpl",
      {
        runner_name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner")
        auth_token  = var.runner_auth_token
      }
    )
  )

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

  tags = var.extra_tags
}



#-------------------------------------------------------------------------------
# CIRCLECI RUNNER CLUSTER AUTO SCALING TRIGGERS
# Cloudwatch metric alarms and auto scaling policies that work in conjunction
# to trigger scaling when job queue length exceeds a specified threshold
#-------------------------------------------------------------------------------


resource "aws_cloudwatch_metric_alarm" "scale_out" {
  #count = length(var.scaling_triggers)

  alarm_name          = "${var.resource_prefix}-circleci-runner-cluster-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = var.metric_name
  namespace           = var.metric_namespace
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Trigger to scale out CircleCI runner cluster."
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    "CircleCI Runner" = var.resource_class
  }

  tags = var.extra_tags
}

resource "aws_cloudwatch_metric_alarm" "scale_in" {
  #count = length(var.scaling_triggers)

  alarm_name          = "${var.resource_prefix}-circleci-runner-cluster-scale-in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = var.metric_name
  namespace           = var.metric_namespace
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Trigger to scale in CircleCI runner cluster."
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    "CircleCI Runner" = var.resource_class
  }

  tags = var.extra_tags
}



resource "aws_autoscaling_policy" "scale_out" {

  name                   = "${var.resource_prefix}-circleci-runner-cluster-scale-out"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.circleci_runner.name
  policy_type            = "StepScaling"

  dynamic "step_adjustment" {
    for_each = var.asg_scale_out_triggers
    content {
      scaling_adjustment          = step_adjustment.value["scaling_adjustment"]
      metric_interval_lower_bound = step_adjustment.value["metric_interval_lower_bound"]
      metric_interval_upper_bound = step_adjustment.value["metric_interval_upper_bound"]
    }
  }
}

resource "aws_autoscaling_policy" "scale_in" {

  name                   = "${var.resource_prefix}-circleci-runner-cluster-scale-in"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.circleci_runner.name
  policy_type            = "StepScaling"

  dynamic "step_adjustment" {
    for_each = var.asg_scale_in_triggers
    content {
      scaling_adjustment          = step_adjustment.value["scaling_adjustment"]
      metric_interval_lower_bound = step_adjustment.value["metric_interval_lower_bound"]
      metric_interval_upper_bound = step_adjustment.value["metric_interval_upper_bound"]
    }
  }
}
