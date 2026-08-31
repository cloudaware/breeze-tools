# Overview

This document describes how to deploy the Breeze 3 agent as a Kubernetes application aiming to
establish the Tunhub connectivity. This deployment runs Breeze as a containerized workload within
Kubernetes.

For the legacy Breeze 2 deployment see [../README.md](../README.md).

# How it works

The Deployment creates a single-replica pod that runs the Breeze agent continuously:

1. **Prerequisite checks** - Run once at container startup:
   - Verify the `/dev/net/tun` device, the TLS certificates and the required environment variables
   - Verify that the container can manipulate netfilter rules
   - Collect the EC2 tags of the node on EKS, which is where the cluster name comes from
   - The container exits with the reason in the log if any check fails, so a misconfigured
     deployment crashloops instead of reporting incorrect data

2. **Agent loop** - Runs the agent every 15 minutes, the same interval as the host installation:
   - Requires `/dev/net/tun` for VPN tunnel creation
   - Runs with `NET_ADMIN` and `NET_RAW` capabilities for network operations
   - Logs to the container stdout, so `kubectl logs` shows each run as it happens
   - Performs readiness checks by verifying that the tunnel interface (`tunhub`) exists

The agent runs as a Kubernetes workload and establishes a VPN tunnel to Tunhub, enabling remote
connectivity without direct network access to the cluster.

# Create Docker image

1. Download the Breeze agent installer and unpack it into this directory:

    ```bash
    cd kubernetes/tunhub/v3
    tar xvzf breeze.example.version.3.<arch>.linux.tgz   # unpacks ./breeze/
    ```

2. Build the Docker image:

    ```bash
    docker build -t registry.example.com/breeze:3.0 .
    ```

   **Note**: TLS certificates are not baked into the image, they are mounted from a Kubernetes
   secret at runtime. `.dockerignore` keeps the certificates of the installer out of the build
   context, so they never reach an image layer.

3. Push the image to your private registry:

    ```bash
    docker push registry.example.com/breeze:3.0
    ```

   **Note**: Replace `registry.example.com/breeze:3.0` with your actual registry host and image tag.

## Alternative: baking certificates into the image

If you prefer to include the TLS certificates in the image (not recommended for security), remove
the two certificate lines from `.dockerignore`, add a `COPY` of them as `etc/breeze.crt` and
`etc/breeze.key` to the Dockerfile after the step that removes the installer certificates, then
comment out the TLS related `volumes` and `volumeMounts` sections in the deployment YAML.

# Run Deployment

The manifests deploy into the `default` namespace. To use another one, change `metadata.namespace`
in the manifest and create the secret below in the same namespace.

## Prerequisites

1. Deploy required RBAC resources:

    ```bash
    kubectl apply -f ../cloudaware-rbac.yaml
    ```

2. Create a Kubernetes secret with your TLS certificates:

    ```bash
    kubectl create secret generic breeze-tls-secret \
      --from-file=tls.crt=breeze/runtime/etc/<id>.crt \
      --from-file=tls.key=breeze/runtime/etc/<id>.key
    ```

   The certificate and the key come with the installer and are named after your Breeze id, the
   secret keys must be `tls.crt` and `tls.key`.

## GKE

1. Ensure the cluster can pull from your registry. For Artifact Registry, grant the node service
   account the `roles/artifactregistry.reader` role; for other registries, add an image pull secret
   to the manifest

2. Update the image reference in `breeze-gke.yaml`

3. Apply the deployment:

    ```bash
    kubectl create -f breeze-gke.yaml
    ```

**GKE Autopilot**: use `breeze-gke-autopilot.yaml`. Autopilot does not allow the `/dev/net/tun`
device to be mounted from the node, so the manifest sets `BREEZE_K8S_CREATE_TUN_DEVICE=true` and the
container creates the device itself.

## AKS

1. Configure AKS-ACR integration (see
   [Microsoft documentation](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration))

2. Update the image reference in `breeze-aks.yaml`

3. Apply the deployment:

    ```bash
    kubectl create -f breeze-aks.yaml
    ```

## EKS

The EKS cluster name is not part of the instance metadata, it is an EC2 tag of the node, and the
agent reads it to identify the cluster. Either let the agent collect the node tags, which is what
`breeze-eks.yaml` does, or name the cluster explicitly, which is what
`breeze-eks-no-imds.yaml` does.

For the node tag collection:

1. Ensure the node group IAM role, or the service account, has the `ec2:DescribeTags` permission.
   Instances that expose their tags through the instance metadata service need no permission at all.

2. Ensure the pods can reach the instance metadata service at `http://169.254.169.254`, which
   requires an instance metadata hop limit of at least 2

3. Update the image reference in `breeze-eks.yaml`

4. Apply the deployment:

    ```bash
    kubectl create -f breeze-eks.yaml
    ```

**Without instance metadata access**: use `breeze-eks-no-imds.yaml` and replace
`<EKS_CLUSTER_ARN>` with the ARN of your cluster. No IAM permission and no metadata access are
needed in that case.

# Configuration

Every setting is an environment variable of the container, so it can be changed with
`kubectl set env deployment/breeze ...` without rebuilding the image.

| Variable | Purpose |
| --- | --- |
| `BREEZE_RUNTIME` | must be `kubernetes`, tells the agent it runs in a pod |
| `BREEZE_K8S_TUNHUB_CLIENT` | must be `enabled`, requests the Tunhub tunnel |
| `BREEZE_K8S_NODE_NAME` | the node the pod runs on, taken from the pod spec |
| `BREEZE_K8S_EKS_CLUSTER_ARN` | names the EKS cluster explicitly, skips the node tag collection |
| `BREEZE_K8S_CREATE_TUN_DEVICE` | `true` makes the container create `/dev/net/tun`, for GKE Autopilot; needs the root image |
| `BREEZE_VERBOSE` | `true` logs at info level, the default in the manifests |
| `BREEZE_DEBUG` | `true` logs at debug level, adds HTTP requests and backtraces |
| `BREEZE_RUN_INTERVAL` | minutes between agent runs, 15 by default |

The server URL and the certificate paths come from the image and normally need no change.

# Verify Deployment

The deployment includes a readiness probe that checks for the `tunhub` tunnel interface. A pod
reporting `1/1 Ready` means the VPN tunnel is established and the agent is working. Note that the
readiness probe starts 15 minutes after the container starts, so allow time for the pod to become
ready.

1. Check pod status:

    ```bash
    kubectl get pods -l app.kubernetes.io/name=breeze
    ```

   Wait for the pod to show `1/1` under the READY column.

2. Check the logs:

    ```bash
    kubectl logs deployment/breeze
    ```

   Expected output starts with `Checking prerequisites...` followed by `prerequisite checks passed`,
   then a run of the agent every 15 minutes with no ERROR lines.

3. Confirm the tunnel interface exists:

    ```bash
    kubectl exec deployment/breeze -- grep tunhub /proc/net/dev
    ```

   If the `tunhub` interface is listed, the VPN tunnel is up and connectivity is established.

# Troubleshooting

The prerequisite checks report what is wrong and the container exits, so start with the logs. You
can also run the checks on their own:

```bash
kubectl exec deployment/breeze -- /opt/cloudaware/breeze/bin/preflight.sh
```

| Message | Cause |
| --- | --- |
| `/dev/net/tun is missing; mount the device or set ...` | the node does not expose the device, or the volume is not mounted. On GKE Autopilot use the Autopilot manifest |
| `... /etc/breeze.crt is not readable; check the secret ...` | the `breeze-tls-secret` secret is missing, or its keys are not named `tls.crt` and `tls.key` |
| `BREEZE_RUNTIME is '', expected 'kubernetes'` | the environment of the container was replaced, restore the variables of the manifest |
| `/usr/sbin/iptables cannot read the rule set; ...` | the container is missing the `NET_ADMIN` capability |
| `the node tags were not collected, ...` | on EKS, the pod cannot reach the instance metadata service, or the role lacks `ec2:DescribeTags`. See the EKS section |
| `the node tags do not name the cluster, ...` | on EKS, no tag of the node names the cluster. Check that the node group is tagged, or name the cluster with `BREEZE_K8S_EKS_CLUSTER_ARN` |
| `BREEZE_K8S_CREATE_TUN_DEVICE is set, but the container does not run as root` | the Autopilot manifest was used with an image built from `unprivileged/Dockerfile`, rebuild with `Dockerfile` |

Certificates are mounted with `subPath`, which Kubernetes never refreshes in a running pod. After
replacing the `breeze-tls-secret` secret, restart the deployment:

```bash
kubectl rollout restart deployment/breeze
```

To raise the log level without rebuilding the image:

```bash
kubectl set env deployment/breeze BREEZE_DEBUG=true
```
