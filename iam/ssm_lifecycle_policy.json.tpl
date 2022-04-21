{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:CompleteLifecycleAction"
            ],
            "Resource": "${asg_arn}",
            "Effect": "Allow"
        }
    ]
}