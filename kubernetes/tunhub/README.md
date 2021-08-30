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
    * `IMAGE_PULL_SECRETS_NAME`

1. Apply the configuration:

    ```bash
    kubectl create -f breeze-agent-deployment-eks.yaml
    ```
## AKS:
1. Edit the deployment YAML file `breeze-agent-deployment-aks.yaml` and replace the next placeholders with the valid values:

    * `CONTAINER_REGISTRY_HOSTNAME`

1. Set up the AKS to ACR integration:
https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration

1. Apply the configuration:

    ```bash
    kubectl create -f breeze-agent-deployment-aks.yaml
    ```
