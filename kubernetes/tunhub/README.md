# Overview

This document describes how to create a Breeze Deployment in a Kubernetes cluster.

# How it works

Container runs a simple daemon which launches Breeze agent every 15 minutes.

# Create Docker image

1. Download the Breeze agent installer and unpack it to the current directory:

    ```bash
    wget breeze-agent.example.version.0.x86_64.linux.tgz
    tar xvzf breeze-agent.example.version.0.x86_64.linux.tgz
    ```

1. Build the Docker images:

    ```bash
    docker build -t breeze-agent -f Dockerfile.breeze-agent .
    ```

1. Push the image to your **private** Docker container registry:

    ```bash
    docker tag breeze-agent:latest CONTAINER_REGISTRY_HOSTNAME/breeze-agent:latest
    docker push breeze-agent:latest CONTAINER_REGISTRY_HOSTNAME/breeze-agent:latest
    ```

1. If you use EKS, also build and push Breeze init image:

    ```
    docker build -t breeze-agent-init -f Dockerfile.breeze-agent-init .
    docker tag breeze-agent-init:latest CONTAINER_REGISTRY_HOSTNAME/breeze-agent-init:latest
    docker push breeze-agent-init:latest CONTAINER_REGISTRY_HOSTNAME/breeze-agent-init:latest
    
    ```

# Run Deployment

## EKS:
1. Edit the deployment YAML file `breeze-agent-deployment-eks.yaml` and replace the next placeholders with the valid values:

    * `CONTAINER_REGISTRY_HOSTNAME`
    * `IMAGE_PULL_SECRETS_NAME` (optional)

2. Make sure that the following AWS metadata endpoints are reachable:
```
latest/api/token
latest/dynamic/instance-identity/document
latest/meta-data/services/partition
latest/meta-data/placement/region
```

3. Ensure that node group IAM role has the `ec2:DescribeTags` action or attach the next policy to the node group IAM role:

   ```
   {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "ec2:DescribeTags",
                "Resource": "*"
            }
        ]
    }
    ```

4. Apply the configuration:

    ```bash
    kubectl create -f breeze-agent-deployment-eks.yaml
    ```

5. If access to metadata endpoints is forbidden Edit the deployment YAML file `breeze-agent-deployment-eks-wo-metadata.yaml` replace the next placeholders with the valid values:

    * `CONTAINER_REGISTRY_HOSTNAME`
    * `EKS_CLUSTER_ARN`
    * `IMAGE_PULL_SECRETS_NAME` (optional)

and apply the configuration:
```bash
kubectl create -f breeze-agent-deployment-eks-wo-metadata.yaml
```

## AKS:
1. Edit the deployment YAML file `breeze-agent-deployment-aks.yaml` and replace the next placeholders with the valid values:

    * `CONTAINER_REGISTRY_HOSTNAME`

2. Set up the AKS to ACR integration:
https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration

3. Apply the configuration:

    ```bash
    kubectl create -f breeze-agent-deployment-aks.yaml
    ```
