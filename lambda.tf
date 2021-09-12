/*
Stuff to create

[X] IAM policy
[X] IAM role
[X] IAM role policy attachment

[X] CW alarms
[X] ASG scaling policies

[X] AWS secrets mgr secrets
[X] KMS key

[X] Lambda function
[X] CW log group
[X] CW scheduled event


VARS:


TODO: 
Add tags to everything
Fix resource names -- dash between resource prefix and "circleci"


*/

resource "aws_iam_role" "queue_depth_lambda_role" {
  name = "${var.resource_prefix}-circleci-runner-lambda"

  assume_role_policy = file("${path.cwd}/iam/lambda_assume_role.json")
}

resource "aws_iam_policy" "queue_depth_lambda_role" {
  name        = "${var.resource_prefix}-circleci-runner-lambda"
  path        = "/"
  description = "Allows a Lambda function to check the CircleCI for the number of queued Runner jobs."

  policy = templatefile(
    "${path.module}/iam/lambda_policy.json.tpl",
    {
      secret_arn    = aws_secretsmanager_secret.queue_depth_lambda_secrets.arn,
      log_group_arn = aws_cloudwatch_log_group.queue_depth_lambda.arn
    }
  )
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.queue_depth_lambda_role.name
  policy_arn = aws_iam_policy.queue_depth_lambda_role.arn
}



resource "aws_lambda_function" "queue_depth" {
  filename      = "${path.cwd}/lambda/function.zip"
  function_name = "${var.resource_prefix}-circleci-runner-queue-depth-monitor"
  role          = aws_iam_role.queue_depth_lambda_role.arn
  handler       = "index.test"

  source_code_hash = filebase64sha256("${path.cwd}/lambda/function.zip")

  runtime = "python3.8"

  # Used by the Lambda function to find the CircleCI API token and Runner resource class stored in Secrets Manager
  environment {
    variables = {
      SECRET_NAME      = aws_secretsmanager_secret_version.queue_depth_lambda_secrets.id,
      SECRET_REGION    = data.aws_region.current.name
      METRIC_NAME      = var.metric_name
      METRIC_NAMESPACE = var.metric_namespace
    }
  }
}

resource "aws_cloudwatch_log_group" "queue_depth_lambda" {
  name = "${var.resource_prefix}-circleci-runner-lambda"

  tags = {
    Foo = "Bar"
  }
}






resource "aws_secretsmanager_secret" "queue_depth_lambda_secrets" {
  name       = "${var.resource_prefix}-circleci-runner-lambda-secrets"
  kms_key_id = var.secrets_manager_kms_key_id != "" ? var.secrets_manager_kms_key_id : aws_kms_key.queue_depth_lambda_secrets[0].id
}

resource "aws_secretsmanager_secret_version" "queue_depth_lambda_secrets" {
  secret_id = aws_secretsmanager_secret.queue_depth_lambda_secrets.id
  secret_string = jsonencode(
    {
      "circle_token" : var.circle_token,
      "resource_class" : var.resource_class
    }
  )
}

resource "aws_kms_key" "queue_depth_lambda_secrets" {
  count                   = var.secrets_manager_kms_key_id != "" ? 0 : 1
  description             = "For encrypting secrets used by CircleCI Runner lambda function."
  deletion_window_in_days = 14
}






resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  for_each = var.scaling_triggers

  alarm_name                = "${var.resource_prefix}-circleci-runner-queue-depth-${each.value.alarm_threshold}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = var.metric_name
  namespace                 = var.metric_namespace
  period                    = each.value.alarm_period
  statistic                 = "Average"
  threshold                 = each.value.alarm_threshold
  alarm_description         = "Trigger to scale out CircleCI runner cluster."
  insufficient_data_actions = []
}


resource "aws_autoscaling_policy" "queue_depth" {
  for_each = aws_cloudwatch_metric_alarm.queue_depth

  name                   = "${var.resource_prefix}-circleci-runner-cluster-scale-at-${each.value.asg_scale_percentage}"
  scaling_adjustment     = each.value.asg_scale_percentage
  adjustment_type        = "PercentChangeInCapacity"
  cooldown               = each.value.asg_scale_cooldown
  autoscaling_group_name = aws_autoscaling_group.circleci_runner.name
}



resource "aws_cloudwatch_event_rule" "run_queue_depth_lambda" {
  name        = "${var.resource_prefix}-circleci-runner-queue-depth-lambda-trigger"
  description = "Run a Lambda function every minute that polls the CircleCI API for the current runner job queue length."

  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "run_queue_depth_lambda" {
  rule = aws_cloudwatch_event_rule.run_queue_depth_lambda.name
  arn  = aws_lambda_function.queue_depth.arn
}