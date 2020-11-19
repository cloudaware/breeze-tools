# Overview

This document describes how to install Breeze Deployment in Kubernetes using Helm.

## Installation

### Install using the Helm chart (recommended)

 1. Install Helm following the [official instructions](https://helm.sh/docs/intro/install/).

 2. Run the following command to install Breeze Agent via Helm, replacing the placeholder values `PLATFORM` (eks|aks), `CONTAINER_REGISTRY_HOSTNAME`, `CONTAINER_REGISTRY_SECRET_NAME`:
    * Helm 3
        ```sh
        helm install breeze-agent ./ --set platform="PLATFORM" --set containerRegistryHostname="CONTAINER_REGISTRY_HOSTNAME" --set containerRegistrySecretsName="CONTAINER_REGISTRY_SECRETS_NAME"
        ```