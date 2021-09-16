import json, urllib3, boto3, base64, os
from botocore.exceptions import ClientError

secret_name   = os.environ['SECRET_NAME']
secret_region = os.environ['SECRET_REGION']
metric_name = os.environ['METRIC_NAME']
metric_namespace = os.environ['METRIC_NAMESPACE']

def get_secret(secret_name, secret_region):

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=secret_region
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            print("Secrets Manager can't decrypt the protected secret text using the provided KMS key.")
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            print("An error occurred on the server side.")
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            print("You provided an invalid value for a parameter.")
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            print("You provided a parameter value that is not valid for the current state of the resource.")
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            print("We can't find the secret that you asked for.")
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
    else:
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            return(secret)
        else:
            decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
            return(decoded_binary_secret)
            


def get_queue_depth(url, headers):
    http = urllib3.PoolManager()
    r = http.request('GET', url, headers=headers)
    r_json = json.loads(r.data.decode("utf-8"))
    return(r_json)
    
    
    

def send_metric_data_to_cw(data, resource_class):
    cloudwatch = boto3.client('cloudwatch')
    cloudwatch.put_metric_data(
            MetricData = [
                {
                    'MetricName': metric_name,
                    'Dimensions': [
                        {
                            'Name': 'CircleCI Runner',
                            'Value': resource_class
                        },
                    ],
                    'Unit': 'None',
                    'Value': data
                },
            ],
            Namespace = metric_namespace
        )
    

def lambda_handler(event, context):
    secrets = json.loads(get_secret(secret_name, secret_region))
    
    endpoint_url = 'https://runner.circleci.com/api/v2/runner/tasks?resource-class=' + secrets['resource_class']
    headers = {'Circle-Token': secrets['circle_token']}
    
    result = get_queue_depth(endpoint_url, headers)
    send_metric_data_to_cw(result["unclaimed_task_count"], secrets['resource_class'])
    return result["unclaimed_task_count"]
