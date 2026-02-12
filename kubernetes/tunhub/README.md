# Overview

This document describes how to deploy the Breeze agent as a Kubernetes application aiming to establish the Tunhub connectivity. This deployment runs Breeze as a containerized workload within Kubernetes.

# How it works

The Deployment creates a single-replica pod with two components:

1. **Init container** - Runs once at pod startup (EKS only):
   - Fetches EC2 instance metadata and tags using IMDSv2
   - Retrieves node tags via AWS EC2 API (requires `ec2:DescribeTags` permission)
   - Stores tag data in a shared volume for the main container

2. **Main container** - Runs the Breeze agent continuously:
   - Executes `breeze-daemon` which runs Breeze on schedule
   - Requires `/dev/net/tun` device for VPN tunnel creation
   - Runs with `NET_ADMIN` and `NET_RAW` capabilities for network operations
   - Runs as non-root user (UID 10000) for security
   - Performs readiness checks by verifying the tunnel interface (`zcat`) exists

The agent runs as a Kubernetes workload and establishes a VPN tunnel to Tunhub, enabling remote connectivity without direct network access to the cluster.

# Create Docker image

1. Download the Breeze agent installer and unpack it to the current directory:

    ```bash
    tar xvzf breeze-agent.example.version.0.x86_64.linux.tgz
    ```

2. Remove TLS certificates from the unpacked directory to avoid baking secrets into the image:

    ```bash
    rm -f breeze-agent/etc/ssl/breeze-agent.crt
    rm -f breeze-agent/etc/ssl/breeze-agent.key
    ```

   **Note**: TLS certificates will be mounted from Kubernetes secrets at runtime.

3. Build Docker image:

   - For EKS (standard):

    ```bash
    docker build -t registry.example.com/breeze-agent:redacted -f Dockerfile .
    ```

   - For AKS and GKE Autopilot builds you **must** use `Dockerfile.root`:

    ```bash
    docker build -t registry.example.com/breeze-agent:redacted -f Dockerfile.root .
    ```

4. Push the image to your private registry:

    ```bash
    docker push registry.example.com/breeze-agent:redacted
    ```

   **Note**: Replace `registry.example.com/breeze-agent:2.0` with your actual registry host and image tag.

## Alternative: Baking certificates into the image

If you prefer to include TLS certificates in the image (not recommended for security):
1. Skip step 2 above to keep certificates in the unpacked directory
2. Build and push the image
3. Comment out the TLS-related `volumes` and `volumeMounts` sections in the deployment YAML

# Run Deployment

## Prerequisites

1. Deploy required RBAC resources:

    ```bash
    kubectl apply -f cloudaware-rbac.yaml
    ```

2. Create a Kubernetes secret with your TLS certificates:

    ```bash
    kubectl create secret generic breeze-tls-secret \
      --from-file=tls.crt=path/to/breeze-agent.crt \
      --from-file=tls.key=path/to/breeze-agent.key
    ```

## EKS

1. Ensure the node group IAM role has `ec2:DescribeTags` permission

2. Verify AWS metadata endpoints are accessible from pods:
   - `latest/api/token`
   - `latest/dynamic/instance-identity/document`
   - `latest/meta-data/services/partition`
   - `latest/meta-data/placement/region`

3. Update the image reference in `breeze-agent-eks.yaml`

4. Apply the deployment:

    ```bash
    kubectl create -f breeze-agent-eks.yaml
    ```

**Alternative**: If metadata access is restricted, use `breeze-agent-eks-wo-metadata.yaml` (replace `<EKS_CLUSTER_ARN>` with actual ARN).

## AKS

**Note**: AKS requires `Dockerfile.root` for image builds.

1. Configure AKS-ACR integration (see [Microsoft documentation](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration))

2. Update the image reference in `breeze-agent-aks.yaml`

3. Apply the deployment:

    ```bash
    kubectl create -f breeze-agent-aks.yaml
    ```

## GKE

1. Ensure cluster has permissions to pull from the registry (use Workload Identity or image pull secrets)

2. Update the image reference in `breeze-agent-gke.yaml`

3. Apply the deployment:

    ```bash
    kubectl create -f breeze-agent-gke.yaml
    ```

**GKE Autopilot**: Use `Dockerfile.root` for builds and `breeze-agent-gke-autopilot.yaml` for deployment.
