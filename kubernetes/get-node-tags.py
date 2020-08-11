import requests
import boto3
import json

region = requests.get('http://169.254.169.254/latest/meta-data/placement/region').content.decode()
instance_id = requests.get('http://169.254.169.254/latest/meta-data/instance-id').content.decode()

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
