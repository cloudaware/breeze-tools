<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Overview](#overview)
- [How it works](#how-it-works)
- [Create Docker image](#create-docker-image)
- [Run DaemonSet](#run-daemonset)

<!-- /TOC -->

# Overview

This document describes how to install Breeze on GKE worker nodes with Container-Optimized OS.
Breeze is to be installed as DaemonSet so that we have an agent on every worker node. Due to the Container-Optimized OS image restrictions (the root filesystem is mounted as read-only to protect system integrity) we need to create and mount an additional disk to every node so that we can store agent’s files there.

# Required tools
* docker
* Kubernetes client (kubectl)
* Google Cloud SDK (gcloud)


# Create Docker image

1. Download the Breeze agent installer and unpack it to the current directory:

    ```bash
    wget breeze-agent.example.version.0.x86_64.linux.tgz
    tar xvzf breeze-agent.example.version.0.x86_64.linux.tgz
    ```

1. Build the Docker image and push it to your **private** container registry:

    ```bash
    docker build -t CONTAINER_REGISTRY_HOSTNAME/breeze-agent-ds:latest .
    docker push CONTAINER_REGISTRY_HOSTNAME/breeze-agent-ds:latest
    ```

# Enable Workload Identity

[Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) allows workloads in your GKE clusters to impersonate Identity and Access Management (IAM) service accounts to access Google Cloud services.
You can [enable Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable-existing-cluster) on an existing Standard cluster by using the following gcloud CLI command:

```bash
gcloud container clusters update <CLUSTER_NAME> \
 --region=<COMPUTE_REGION> \
 --workload-pool=<PROJECT_ID>.svc.id.goog
```

# Migrate existing workloads to Workload Identity
Existing node pools are unaffected, but any new node pools in the cluster use Workload Identity.
To [modify an existing node pool](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#option_2_node_pool_modification) to use Workload Identity, run the following command:

```bash
gcloud container node-pools update <NODEPOOL_NAME> \
   --cluster=<CLUSTER_NAME> \
   --workload-metadata=GKE_METADATA
```

# Create service accounts
Create a Kubernetes service account (KSA) and a Google service account (GSA). Adjust PROJECT_ID and other values if needed in gcloud-workload-identity.sh and run the script:

```bash
bash gcloud-workload-identity.sh
```

# Run DaemonSet

1. Edit the DaemonSet configuration file `ds-breeze-agent.yaml` and replace the next placeholders with the valid values:

    * `PROJECT_ID`
    * `CONTAINER_REGISTRY_HOSTNAME`

1. Create the DaemonSet:

    ```bash
    kubectl create -f ds-breeze-agent.yaml
    ```
