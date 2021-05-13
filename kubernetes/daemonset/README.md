<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Overview](#overview)
- [How it works](#how-it-works)
- [Create Docker image](#create-docker-image)
- [Run DaemonSet](#run-daemonset)

<!-- /TOC -->

# Overview

This document describes how to create the DaemonSet to run the Breeze agent on every node of the Kubernetes cluster.

# How it works

DaemonSet start the container with Breeze agent installer. The container have two bind mounts:

* `host:/opt > container:/opt` - used for the Breeze agent installation from container to the host filesystem
* `host:/ > container:/var/root` - used for the agent launching in the chroot environment

Container run two commands:

1. Install the Breeze agent to the `/opt` directory
2. Run the simple daemon which run the Breeze agent every 15 minutes

# Create Docker image

1. Download the Breeze agent installer and unpack it to the current directory:

    ```bash
    wget breeze-agent.example.version.0.x86_64.linux.tgz
    tar xvzf breeze-agent.example.version.0.x86_64.linux.tgz
    ```

1. Build the Docker image:

    ```bash
    docker build -t breeze-agent-ds .
    ```

1. Push the image to your **private** Docker container registry:

    ```bash
    docker tag breeze-agent-ds:latest CONTAINER_REGISTRY_HOSTNAME/breeze-agent-ds:latest
    docker push breeze-agent-ds:latest CONTAINER_REGISTRY_HOSTNAME/breeze-agent-ds:latest
    ```

# Run DaemonSet

1. Edit the DaemonSet configuration file `ds-breeze-agent.yaml` and replace the next placeholders with the valid values:

    * `CONTAINER_REGISTRY_HOSTNAME`
    * `IMAGE_PULL_SECRETS_NAME`

1. Create the new DaemonSet:

    ```bash
    kubectl create -f ds-breeze-agent.yaml
    ```
