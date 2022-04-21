{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "${ssm_automation_role_arn}",
            "Effect": "Allow"
        }
    ]
}