/*
Stuff to create

[X] IAM policy
[X] IAM role
[X] IAM role policy attachment

[ ] CW alarms
[ ] ASG scaling policies

[X] AWS secrets mgr secrets
[ ] KMS key

[X] Lambda function
[X] CW log group


VARS:


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



resource "aws_lambda_function" "test_lambda" {
  filename      = "${path.cwd}/lambda/function.zip"
  function_name = "${var.resource_prefix}-circleci-runner-queue-depth-monitor"
  role          = aws_iam_role.queue_depth_lambda_role.arn
  handler       = "index.test"

  source_code_hash = filebase64sha256("${path.cwd}/lambda/function.zip")

  runtime = "python3.8"

  # Used by the Lambda function to find the CircleCI API token and Runner resource class stored in Secrets Manager
  environment {
    variables = {
      SECRET_NAME   = aws_secretsmanager_secret_version.queue_depth_lambda_secrets.id,
      SECRET_REGION = data.aws_region.current.name
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
  name = "${var.resource_prefix}-circleci-runner-lambda-secrets"
}

resource "aws_secretsmanager_secret_version" "queue_depth_lambda_secrets" {
  secret_id = aws_secretsmanager_secret.queue_depth_lambda_secrets.id
  secret_string = jsonencode(
    {
      "circle_token" : "${var.circle_token}",
      "resource_class" : "${var.resource_class}"
    }
  )
}