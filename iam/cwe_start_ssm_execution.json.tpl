{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "ssm:StartautomationExecution"
            ],
            "Resource": "${ssm_doc_arn}",
            "Effect": "Allow"
        }
    ]
}