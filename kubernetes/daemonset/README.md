<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Overview](#overview)
- [How it works](#how-it-works)
- [Create Docker image](#create-docker-image)
- [Run DaemonSet](#run-daemonset)

<!-- /TOC -->

# Overview

This document describes how to install the Breeze agent on Kubernetes cluster nodes using a DaemonSet. This is an alternative to traditional SSH-based installation where administrators manually log into each instance to install software.

**Important**: This DaemonSet does not run Breeze as a Kubernetes application. Instead, it installs Breeze directly on the underlying host machines. The agent runs natively on each node's operating system, scheduled via systemd or cron.

# How it works

The DaemonSet deploys a pod on each Kubernetes node with two components:

1. **Init container** - Runs once per pod startup to install Breeze agent on the host:
   - Mounts host directories: `/opt`, `/etc`, `/var/log`, and `/proc`
   - Copies agent files from the container to `/opt/breeze-agent` on the host
   - Configures systemd timer (preferred) or cron job to run the agent every 15 minutes
   - Detects AL2023/RHEL 10 hosts and installs required dependencies (libxcrypt-compat)
   - Uses `nsenter` to interact with the host's systemd

2. **Logger container** - Runs continuously to stream agent logs:
   - Tails `/var/log/breeze-agent.log` from the host
   - Outputs logs to stdout for Kubernetes log collection

The agent runs natively on the host OS, not as a containerized application. The DaemonSet ensures every node in the cluster has the agent installed and keeps logs accessible via `kubectl logs`.

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

   **Note**: TLS certificates will be mounted from Kubernetes secrets at runtime (see Run DaemonSet section).

3. Build the Docker image:

    ```bash
    docker build -t registry.example.com/breeze-agent:host-installer-latest .
    ```

4. Push the image to your **private** Docker container registry:

    ```bash
    docker push registry.example.com/breeze-agent:host-installer-latest
    ```

   **Note**: Replace `registry.example.com` with your actual container registry hostname.

## Alternative: Baking certificates into the image

If you prefer to include TLS certificates in the image (not recommended for security):
1. Skip step 2 above to keep certificates in the unpacked directory
2. Build and push the image
3. Comment out the TLS-related `volumes` and `volumeMounts` sections in `breeze-agent-host-installer.yaml`

# Run DaemonSet

1. Create a Kubernetes secret with your TLS certificates:

    ```bash
    kubectl create secret tls breeze-tls-secret \
      --cert=path/to/breeze-agent.crt \
      --key=path/to/breeze-agent.key
    ```

2. Update the image reference in `breeze-agent-host-installer.yaml` if using a different registry or tag

3. Create the DaemonSet:

    ```bash
    kubectl create -f breeze-agent-host-installer.yaml
    ```

4. Verify the installation:

    ```bash
    # Check DaemonSet status
    kubectl get daemonset breeze-agent-ds
    
    # View logs from a specific node
    kubectl logs -l app=breeze-agent -c logger
    
    # Verify agent is running on a node (SSH to node)
    systemctl status breeze-agent.service
    ```

## Uninstalling

To remove the DaemonSet:
```bash
kubectl delete -f breeze-agent-host-installer.yaml
```

**Note**: This only removes the DaemonSet pods. The agent remains installed on the host nodes. To fully uninstall, SSH to each node and manually remove `/opt/breeze-agent` and the systemd timer or cron job.
