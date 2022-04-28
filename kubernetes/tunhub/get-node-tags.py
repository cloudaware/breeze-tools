import requests
import boto3
import json

def get_metadata(path, token, errors):
    response = requests.get(
        f'http://169.254.169.254/{path}',
        headers={"X-aws-ec2-metadata-token": token}
    )
    if response.status_code == 200:
        return response.content.decode()
    else:
        errors.append(f'Failed to call {path}: {response.text}')
        return None

response = requests.put(
    'http://169.254.169.254/latest/api/token',
    headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"}
)
if response.status_code == 200:
    token = response.content.decode()
else:
    raise Exception('Failed to get IDMSv2 token')

errors = []

region = get_metadata('latest/meta-data/placement/region', token, errors)
instance_id = get_metadata('latest/meta-data/instance-id', token, errors)
document = get_metadata('latest/dynamic/instance-identity/document', token, errors)
partition = get_metadata('latest/meta-data/services/partition', token, errors)

if not all([region, instance_id, document, partition]):
    raise Exception(f'Errors: {errors}')

client = boto3.client('ec2', region_name=region)
response = client.describe_tags(
    Filters=[
        {
            'Name': 'resource-id',
            'Values': [instance_id]
        },
    ]
)

with open('/breeze-data/node-tags.json', 'w') as file:
    json.dump(list(map(lambda x: dict({x.get('Key'): x.get('Value')}), response.get('Tags'))), file)
