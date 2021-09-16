{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "putMetricsInCloudwatch",
            "Effect": "Allow",
            "Action": "cloudwatch:PutMetricData",
            "Resource": "*"
        },
        {
            "Sid": "allowAccessToSecretMgrSecrets",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${secret_arn}"
        },
        {
            "Sid": "allowAccessToCloudwatchLogs",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "${log_group_arn}"
        },
        {
            "Sid": "decryptSecretsWithKmsKey",
            "Effect": "Allow",
            "Action": "kms:Decrypt",
            "Resource": "${kms_key_arn}"
        }


    ]
}