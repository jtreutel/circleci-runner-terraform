

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



resource "aws_placement_group" "circleci_runner" {
  name     = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner-pg"
  strategy = "spread"

  tags = var.extra_tags
}

resource "aws_autoscaling_group" "circleci_runner" {
  name                      = local.asg_name
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

  initial_lifecycle_hook {
    name                 = "%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}linux-cci-runner-active-job-check"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"

    #notification_target_arn = "arn:aws:sqs:us-east-1:444455556666:queue1*"
    #role_arn                = "arn:aws:iam::123456789012:role/S3Access"

    default_result       = "CONTINUE" #If heartbeat timeout is reached, instance will still terminate, but subsequent lifecycle hooks are still allowed to run on the instance prior to termination
    heartbeat_timeout    = 7200  #Instance will remaining in a "wait" state for up to 12 hours
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
        Name = format("%{if var.resource_prefix != ""}${var.resource_prefix}-%{endif}circleci-runner"),
        circleciRunner = "true"
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


# Can't remember why this is here.
#parameters {
#  ASGName = local.asg_name
#}

resource "aws_ssm_document" "check_runner_agent_status" {
  name            = "circleci-check-runner-agent-status"
  document_format = "YAML"
  document_type   = "Automation"

  content = file("${path.module}/ssm/check_runner_agent.yml")
}





###
# IAM Stuff for SSM
###

#Lets SSM run commands on EC2 instances and complete lifecycle hook actions
resource "aws_iam_role" "ssm_actions" {
  name = "${var.resource_prefix}-circleci-runner-ssm"

  assume_role_policy = file("${path.cwd}/iam/ssm_assume_role.json")

  tags = var.extra_tags
}

resource "aws_iam_policy" "ssm_asg_lifecycle_completion" {
  name        = "${var.resource_prefix}-circleci-runner-ssm-asg-lifecycle-completion"
  path        = "/"
  description = "Allows SSM to complete lifecycle hook actions on CircleCI Runners."

  policy = templatefile(
    "${path.module}/iam/ssm_lifecycle_policy.json.tpl",
    {
      asg_arn = aws_autoscaling_group.circleci_runner.arn
    }
  )

  tags = var.extra_tags
}

resource "aws_iam_role_policy_attachment" "ssm_asg_lifecycle_completion" {
  role       = aws_iam_role.ssm_actions.name
  policy_arn = aws_iam_policy.ssm_asg_lifecycle_completion.arn
}


resource "aws_iam_policy" "ssm_automation" {
  name        = "${var.resource_prefix}-circleci-runner-ssm-automaton"
  path        = "/"
  description = "Allows SSM to run specific commands on CircleCI Runners."

  policy = templatefile(
    "${path.module}/iam/ssm_automation_policy.json.tpl",
    {
      aws_region = var.aws_region
    }
  )

  tags = var.extra_tags
}

resource "aws_iam_role_policy_attachment" "ssm_automation" {
  role       = aws_iam_role.ssm_actions.name
  policy_arn = aws_iam_policy.ssm_automation.arn
}


#######
# IAM Stuff for Cloudwatch Events
#######

resource "aws_iam_role" "cwe_invoke_ssm" {
  name = "${var.resource_prefix}-circleci-runner-cwe"

  assume_role_policy = file("${path.cwd}/iam/cwe_assume_role.json")

  tags = var.extra_tags
}

resource "aws_iam_policy" "cwe_start_ssm_execution" {
  name        = "${var.resource_prefix}-circleci-runner-cwe-start-ssm-execution"
  path        = "/"
  description = "Allows Cloudwatch Events to trigger SSM document execution."

  policy = templatefile(
    "${path.module}/iam/cwe_start_ssm_execution.json.tpl",
    {
      ssm_doc_arn = aws_ssm_document.check_runner_agent_status.arn
    }
  )

  tags = var.extra_tags
}

resource "aws_iam_policy" "cwe_pass_role" {
  name        = "${var.resource_prefix}-circleci-runner-cwe-pass-role"
  path        = "/"
  description = "Allows this role to assume the SSM automation role."

  policy = templatefile(
    "${path.module}/iam/cwe_pass_role.json.tpl",
    {
      ssm_automation_role_arn = aws_iam_role.ssm_actions.arn
    }
  )

  tags = var.extra_tags
}

resource "aws_iam_role_policy_attachment" "cwe_start_ssm_execution" {
  role       = aws_iam_role.cwe_invoke_ssm.name
  policy_arn = aws_iam_policy.cwe_start_ssm_execution.arn
}

resource "aws_iam_role_policy_attachment" "cwe_pass_role" {
  role       = aws_iam_role.cwe_invoke_ssm.name
  policy_arn = aws_iam_policy.cwe_pass_role.arn
}


#########
# Cloudwatch Events
#########

resource "aws_cloudwatch_event_rule" "trigger_" {
  name        = "${var.resource_prefix}-circleci-runner-lifecycle-trigger"
  description = "Trigger SSM automation to keep Runner alive when ASG tries to terminate it."

  event_pattern = tojson(file("${path.module}/..."))

  tags = var.extra_tags
}

resource "aws_cloudwatch_event_target" "run_queue_depth_lambda" {
  rule = aws_cloudwatch_event_rule.run_queue_depth_lambda.name
  arn  = aws_lambda_function.queue_depth.arn
}