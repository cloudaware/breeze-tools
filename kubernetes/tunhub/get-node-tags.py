import requests
import boto3
import json

response = requests.put(
    'http://169.254.169.254/latest/api/token',
    headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"}
)
if response.status_code == 200:
    token = response.content.decode()
else:
    raise Exception('Failed to get IDMSv2 token')

region, instance_id = None, None
errors = []

response = requests.get(
    'http://169.254.169.254/latest/meta-data/placement/region',
    headers={"X-aws-ec2-metadata-token": token}
)
if response.status_code == 200:
    region = response.content.decode()
else:
    errors.append(f'Failed to get region: {response.text}')

response = requests.get(
    'http://169.254.169.254/latest/meta-data/instance-id',
    headers={"X-aws-ec2-metadata-token": token}
)
if response.status_code == 200:
    instance_id = response.content.decode()
else:
    errors.append(f'Failed to get instnce ID: {response.text}')

if not all([region, instance_id]):
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
