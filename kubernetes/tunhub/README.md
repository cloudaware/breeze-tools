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

2. Build Docker image (general):

    ```bash
    docker build -t registry.example.com/breeze-agent:redacted -f Dockerfile .
    ```

   - For AKS builds you **must** use `Dockerfile.aks`:

    ```bash
    docker build -t registry.example.com/breeze-agent:redacted -f Dockerfile.aks .
    ```

3. Push the image to your private registry:

    ```bash
    docker push registry.example.com/breeze-agent:redacted
    ```

   - Replace `registry.example.com/breeze-agent:redacted` with your actual registry host and image tag.

# Required RBAC

- Make sure to deploy `cloudaware-rbac.yaml`. This is required for the Breeze agent to function correctly:

    ```bash
    kubectl apply -f cloudaware-rbac.yaml
    ```

# Run Deployment

## EKS

1. Make sure that the following AWS metadata endpoints are reachable:
   - `latest/api/token`
   - `latest/dynamic/instance-identity/document`
   - `latest/meta-data/services/partition`
   - `latest/meta-data/placement/region`

2. Ensure the node group IAM role allows `ec2:DescribeTags` or attach the required policy.

3. Replace the image placeholder in the manifest with the actual value and apply the deployment:

    ```bash
    kubectl create -f breeze-agent-eks.yaml
    ```

- If metadata access is forbidden, use `breeze-agent-eks-wo-metadata.yaml` (replace `<EKS_CLUSTER_ARN>` placeholder with an actual ARN ) and apply it.

## AKS

1. Configure AKS-ACR integration (see Microsoft docs).

2. Replace the image placeholder in the manifest with the actual value and apply the deployment:

    ```bash
    kubectl create -f breeze-agent-aks.yaml
    ```

## GKE

1. Ensure cluster has required permissions to pull from the registry (use Workload Identity or image pull secrets).

2. Replace the image placeholder in the manifest with the actual value and apply the deployment:

    ```bash
    kubectl create -f breeze-agent-gke.yaml
    ```
