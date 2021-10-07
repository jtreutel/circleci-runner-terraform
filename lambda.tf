
#-------------------------------------------------------------------------------
# LAMBDA FUNCTION & SUPPORTING RESOURCES
# Lambda function, Cloudwatch log group for storing Lambda function output,
# IAM resources so the Lambda can talk to other AWS services, Cloudwatch event
# that runs the Lambda function every minute to check for queued jobs
#-------------------------------------------------------------------------------

resource "aws_lambda_function" "queue_depth" {
  filename      = "${path.cwd}/lambda/get_queue_depth.zip"
  function_name = "${var.resource_prefix}-circleci-runner-queue-depth-monitor"
  role          = aws_iam_role.queue_depth_lambda_role.arn
  handler       = "get_queue_depth.lambda_handler"

  source_code_hash = filebase64sha256("${path.cwd}/lambda/get_queue_depth.zip")

  runtime = "python3.8"

  # Used by the Lambda function to find the CircleCI API token and Runner resource class stored in Secrets Manager
  environment {
    variables = {
      SECRET_NAME      = aws_secretsmanager_secret.queue_depth_lambda_secrets.name,
      SECRET_REGION    = data.aws_region.current.name
      METRIC_NAME      = var.metric_name
      METRIC_NAMESPACE = var.metric_namespace
    }
  }

  tags = var.extra_tags
}

resource "aws_cloudwatch_log_group" "queue_depth_lambda" {
  name = "${var.resource_prefix}-circleci-runner-lambda"

  tags = var.extra_tags
}


resource "aws_iam_role" "queue_depth_lambda_role" {
  name = "${var.resource_prefix}-circleci-runner-lambda"

  assume_role_policy = file("${path.cwd}/iam/lambda_assume_role.json")

  tags = var.extra_tags
}

resource "aws_iam_policy" "queue_depth_lambda_role" {
  name        = "${var.resource_prefix}-circleci-runner-lambda"
  path        = "/"
  description = "Allows a Lambda function to check the CircleCI for the number of queued Runner jobs."

  policy = templatefile(
    "${path.module}/iam/lambda_policy.json.tpl",
    {
      secret_arn    = aws_secretsmanager_secret.queue_depth_lambda_secrets.arn,
      log_group_arn = aws_cloudwatch_log_group.queue_depth_lambda.arn,
      kms_key_arn   = var.secrets_manager_kms_key_id != "" ? data.aws_kms_key.existing_key[0].arn : aws_kms_key.queue_depth_lambda_secrets[0].arn
    }
  )

  tags = var.extra_tags
}

resource "aws_iam_role_policy_attachment" "queue_depth_lambda_role" {
  role       = aws_iam_role.queue_depth_lambda_role.name
  policy_arn = aws_iam_policy.queue_depth_lambda_role.arn
}


resource "aws_cloudwatch_event_rule" "run_queue_depth_lambda" {
  name        = "${var.resource_prefix}-circleci-runner-queue-depth-lambda-trigger"
  description = "Run a Lambda function every minute that polls the CircleCI API for the current runner job queue length."

  schedule_expression = "rate(1 minute)"

  tags = var.extra_tags
}

resource "aws_cloudwatch_event_target" "run_queue_depth_lambda" {
  rule = aws_cloudwatch_event_rule.run_queue_depth_lambda.name
  arn  = aws_lambda_function.queue_depth.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.queue_depth.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.run_queue_depth_lambda.arn 
}


#-------------------------------------------------------------------------------
# AWS SECRETS MANAGER RESOURCES
# AWS Secrets Manager secret that stores the CircleCI API token and the name
# of the target resource class.
#-------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "queue_depth_lambda_secrets" {
  name       = "${var.resource_prefix}-circleci-runner-lambda-secrets-${random_string.random.result}"
  kms_key_id = var.secrets_manager_kms_key_id != "" ? var.secrets_manager_kms_key_id : aws_kms_key.queue_depth_lambda_secrets[0].id

  tags = var.extra_tags
}

resource "random_string" "random" {
  length  = 8
  special = false

  keepers = {
    circle_token   = var.circle_token
    resource_class = var.resource_class
  }
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
  count = var.secrets_manager_kms_key_id != "" ? 0 : 1

  description             = "For encrypting secrets used by CircleCI Runner lambda function."
  deletion_window_in_days = 14

  tags = {
    Name = "${var.resource_prefix}-circleci-runner-queue-depth-secrets-key"
  }
}

resource "aws_kms_alias" "queue_depth_lambda_secrets" {
  count = var.secrets_manager_kms_key_id != "" ? 0 : 1

  name          = "alias/${var.resource_prefix}-circleci-runner-queue-depth-secrets-key"
  target_key_id = aws_kms_key.queue_depth_lambda_secrets[0].key_id
}







