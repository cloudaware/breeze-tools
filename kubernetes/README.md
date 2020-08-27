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
    docker build -t breeze-agent-init -f Dockerfile.breeze-agent-init .

    docker build -t breeze-agent -f Dockerfile.breeze-agent .
    ```

1. Push the image to your **private** Docker container registry:

    ```bash
    docker tag breeze-agent-init:latest CONTAINER_REGISTRY_URI/breeze-agent-init:latest
    docker push breeze-agent-init:latest CONTAINER_REGISTRY_URI/breeze-agent-init:latest

    docker tag breeze-agent:latest CONTAINER_REGISTRY_URI/breeze-agent:latest
    docker push breeze-agent:latest CONTAINER_REGISTRY_URI/breeze-agent:latest
    ```

# Run Deployment

1. Edit the deployment YAML file `breeze-agent-deployment.yaml` and replace the next placeholders with the valid values:

    * `CONTAINER_REGISTRY_URI`
    * `IMAGE_PULL_SECRET_NAME`

1. Apply the configuration:

    ```bash
    kubectl create -f breeze-agent-deployment.yaml
    ```
