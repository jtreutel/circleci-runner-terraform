{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "ssm:DescribeInstanceInformation",
                "ssm:ListCommands",
                "ssm:ListCommandInvocations"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ssm:SendCommand"
            ],
            "Resource": "arn:aws:ssm:${aws_region}::document/AWS-RunShellScript",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ssm:SendCommand"
            ],
            "Resource": "arn:aws:ec2:*:*:instance/*",
            "Effect": "Allow",
            "Condition": {
                "StringEquals": {
                    "aws:TagKeys": [
                        "circleciRunner"
                    ]
                }
            }
        }
    ]
}