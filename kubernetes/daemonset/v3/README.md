# Overview

This document describes how to install the Breeze 3 agent on the nodes of a Kubernetes cluster with
a DaemonSet. It is an alternative to the SSH based installation, where an administrator logs into
every node to install the agent.

For the legacy Breeze 2 DaemonSet see [../README.md](../README.md).

**Important**: this DaemonSet does not run Breeze as a Kubernetes application. It installs Breeze on
the operating system of every node, where the agent runs from a systemd timer or a cron job. To run
the agent as a Kubernetes workload, which is what the Tunhub connectivity needs, see
[../../tunhub/v3/README.md](../../tunhub/v3/README.md).

# How it works

The DaemonSet places a pod on every node, with two containers:

1. **Init container** — installs the agent on the node, once per pod start:
   - checks that it can enter the namespaces of the node and that the certificates are mounted, and
     exits with the reason in the log when either fails
   - copies the installer onto the node, which is what the hostPath mount is for
   - runs the stock `breeze/install.sh` in the namespaces of the node through `nsenter`, so the
     agent is installed by the Ruby, the package manager and the scheduler of the node, exactly as
     it is over SSH: the runtime lands in the home directory of the agent, the agent gems are
     installed with the bundled Ruby, and `breeze scheduler enable` writes a systemd timer, or a
     cron job on a node without systemd
   - skips the installation when the node already runs the build carried by the image
   - verifies the installation by running the agent on the node, and removes the staged installer

2. **Logger container** — runs for as long as the pod does:
   - tails `var/log/breeze.log` of the agent on the node into its stdout, so `kubectl logs` shows
     the runs of an agent that is not running in this pod at all

The agent then runs on the node every 15 minutes, started by the scheduler of the node rather than
by Kubernetes. The pod only installs it and streams its log.

# Requirements

- **a manifest that matches the node image.** The agent runs on the node, so where it is installed
  and how it is started follow from the node image. There is one manifest per layout, and the
  installer picks up everything else by reading the node:

  | Node image | Manifest | The agent is installed in |
  | --- | --- | --- |
  | Ubuntu, Amazon Linux, RHEL, Debian, SUSE and other distributions with a writable `/opt` | `breeze-host-installer.yaml` | `/opt/cloudaware/breeze` |
  | Container-Optimized OS | `breeze-host-installer-cos.yaml` | `/var/lib/cloudaware/breeze`, see [Container-Optimized OS](#container-optimized-os) |

  Both are equally supported, and a cluster can run both at once, see
  [Mixed node pools](#mixed-node-pools).

  A node image that offers no writable location for the agent and no way to schedule it, Bottlerocket
  and Talos among them, cannot run a host installation at all.

- the pod needs `hostPID: true`, the `SYS_ADMIN` capability and an unconfined AppArmor profile to
  reach the node. The manifest sets all three. On a node that enforces AppArmor, which is every GKE
  node and every Ubuntu node, the default profile of the container runtime denies the agent
  installer the access to the node it needs, and the installation fails with `the namespaces of the
  node cannot be entered`. On a cluster older than Kubernetes 1.30, replace the `appArmorProfile`
  field of the manifest with the annotation on the pod template:

    ```yaml
    container.apparmor.security.beta.kubernetes.io/install: unconfined
    ```

- in a cluster that enforces Pod Security admission the namespace has to allow the `privileged`
  policy:

    ```bash
    kubectl label namespace default pod-security.kubernetes.io/enforce=privileged
    ```

# Create Docker image

1. Download the Breeze agent installer and unpack it into this directory:

    ```bash
    cd kubernetes/daemonset/v3
    tar xvzf breeze.example.version.3.<arch>.linux.tgz   # unpacks ./breeze/
    ```

   Unpack the build for the architecture and the libc of the nodes, because it is the node that
   runs it, not the container.

2. Build the Docker image:

    ```bash
    docker build -t registry.example.com/breeze:host-installer-3.0 .
    ```

   **Note**: TLS certificates are not baked into the image, they are mounted from a Kubernetes
   secret at runtime. `.dockerignore` keeps the certificates of the installer out of the build
   context, so they never reach an image layer.

3. Push the image to your **private** container registry:

    ```bash
    docker push registry.example.com/breeze:host-installer-3.0
    ```

   **Note**: replace `registry.example.com/breeze:host-installer-3.0` with your actual registry host
   and image tag.

## Alternative: baking certificates into the image

If you prefer to include the TLS certificates in the image (not recommended for security), remove
the two certificate lines from `.dockerignore`, add a `COPY` of them as `runtime/etc/breeze.crt` and
`runtime/etc/breeze.key` to the Dockerfile after the step that removes the installer certificates,
then comment out the TLS related `volumes` and `volumeMounts` sections in
`breeze-host-installer.yaml`.

# Run DaemonSet

The manifest deploys into the `default` namespace. To use another one, change `metadata.namespace`
in the manifest and create the secret below in the same namespace.

1. Create a Kubernetes secret with your TLS certificates:

    ```bash
    kubectl create secret generic breeze-tls-secret \
      --from-file=tls.crt=breeze/runtime/etc/<id>.crt \
      --from-file=tls.key=breeze/runtime/etc/<id>.key
    ```

   The certificate and the key come with the installer and are named after your Breeze id, the
   secret keys must be `tls.crt` and `tls.key`.

2. Update the image reference in `breeze-host-installer.yaml`

3. Create the DaemonSet that matches the node image, see [Requirements](#requirements):

    ```bash
    kubectl create -f breeze-host-installer.yaml        # a node image with a writable /opt
    kubectl create -f breeze-host-installer-cos.yaml    # Container-Optimized OS
    ```

   By default the pod is not placed on tainted nodes, control plane nodes among them. To install the
   agent there as well, uncomment the `tolerations` section of the manifest.

## Container-Optimized OS

Container-Optimized OS keeps the root filesystem read-only and mounts the stateful partition
`noexec`, so the agent is installed on the stateful partition and started from there.
`breeze-host-installer-cos.yaml` sets that up, and there is nothing to configure:

- the agent is installed in `/var/lib/cloudaware/breeze`, and the installer rewrites the home
  directory of the agent to match
- that directory is bind mounted onto itself and remounted without `noexec`, by
  `bin/cos-exec-mount.sh`, which runs from the systemd unit of the agent as well, before every run
- `HOME` is set to a directory of the agent, since the home directory of root is on the read-only
  filesystem

One property is worth knowing, because it shows up as node behaviour rather than as an error.
`/etc` is an overlay whose upper layer is a tmpfs, so **a reboot takes the systemd units of the
agent with it**, while the agent itself, on the stateful partition, survives. The DaemonSet pod
starts with the node and enables the scheduler again without reinstalling, so the node is back on
schedule about a minute after it is Ready, and reports at the next quarter hour. Keeping the
DaemonSet in place is therefore what keeps a Container-Optimized OS node reporting across reboots.

## Mixed node pools

A cluster can run both manifests at once. The Container-Optimized OS one already selects its nodes
with `cloud.google.com/gke-os-distribution: cos`; add the complementary selector to
`breeze-host-installer.yaml` so that the two do not overlap, for example:

```yaml
      nodeSelector:
        cloud.google.com/gke-os-distribution: ubuntu
```

The installer also reads the node it runs on and stops with the name of the manifest to use when it
is given the wrong one, so a mismatch fails before anything is installed rather than installing the
wrong layout.

# Configuration

The agent is configured through `/opt/cloudaware/breeze/etc/vars.sh` on the node. The DaemonSet
writes that file, so the settings belong to the manifest rather than to the image:

| Variable | Purpose |
| --- | --- |
| `BREEZE_HOST_VARS` | lines written to `etc/vars.sh` of the node, `BREEZE_VERBOSE=true` by default. They are written after the settings the node needs, so they can override them |
| `BREEZE_FORCE_INSTALL` | `true` reinstalls the agent even when the node already runs the build of the image |

The settings worth putting in `BREEZE_HOST_VARS`:

| Variable | Purpose |
| --- | --- |
| `BREEZE_VERBOSE` | `true` logs at info level, a handful of lines per run |
| `BREEZE_DEBUG` | `true` logs at debug level, adds HTTP requests and backtraces |

A change takes effect at the next pod start:

```bash
kubectl set env daemonset/breeze-host-installer BREEZE_HOST_VARS="BREEZE_DEBUG=true"
```

The server URL and the certificate paths come from the image and normally need no change.

# Verify installation

1. Check the DaemonSet status:

    ```bash
    kubectl get daemonset breeze-host-installer       # or breeze-host-installer-cos
    ```

   `DESIRED` and `READY` equal means every node has been through the installation.

2. Check what the installation did on each node:

    ```bash
    kubectl logs -l app.kubernetes.io/name=breeze-host-installer -c install
    ```

   The last line is `the agent is installed on the node, the first run follows within 15 minutes`,
   preceded by the version of the agent and by `scheduler: enabled`.

3. Check the agent runs:

    ```bash
    kubectl logs -l app.kubernetes.io/name=breeze-host-installer -c logger
    ```

   Until the first run of the agent, up to 15 minutes after the installation, the logger reports
   that it is waiting for the log file. After that it shows a run every 15 minutes with no ERROR
   lines.

4. On the node itself:

    ```bash
    systemctl status breeze.timer
    ```

# Troubleshooting

The init container reports what is wrong and exits, so start with its log.

| Message | Cause |
| --- | --- |
| `the namespaces of the node cannot be entered: ...` | the message quotes what `nsenter` reported. `Operation not permitted` is the AppArmor profile or a missing `SYS_ADMIN` capability, see [Requirements](#requirements) |
| `Read-only file system` while staging the installer | the location the manifest mounts is read-only on this node image, and no manifest here matches it, see [Requirements](#requirements) |
| `/var/lib/cloudaware of the node is not mounted into the container, ...` | the manifest does not match the node image. Apply `breeze-host-installer-cos.yaml` on Container-Optimized OS nodes |
| the agent is installed but no run happens after a node reboot | on Container-Optimized OS the schedule is restored by the DaemonSet pod, check that the pod on that node is running |
| `ERROR rubygems: read-only file system @ dir_s_mkdir - /root/.cache` in the agent log | an agent installed by a DaemonSet older than this one, which did not set `HOME`. Roll out the current image |
| `PID 1 is the container rather than the node, ...` | `hostPID: true` is missing from the pod spec |
| `... is not readable, check the breeze-tls-secret secret ...` | the `breeze-tls-secret` secret is missing, or its keys are not named `tls.crt` and `tls.key` |
| `the installer failed on the node, its output is in ...` | the installation itself failed. The full output of the installer stays in that file on the node |
| the pod stays in `Init`, no log yet | the image is being pulled, or the installation is running. It takes about a minute on a node that does not have the agent yet |
| the logger keeps printing `waiting for ...` | the agent has not run yet, or the scheduler of the node is not running it. Check `systemctl status breeze.timer` on the node |

The certificates are mounted with `subPath`, which Kubernetes never refreshes in a running pod, and
they are copied to the node during the installation. After replacing the `breeze-tls-secret` secret,
reinstall on every node:

```bash
kubectl set env daemonset/breeze-host-installer BREEZE_FORCE_INSTALL=true
kubectl rollout restart daemonset/breeze-host-installer
```

To raise the log level of the agent, see [Configuration](#configuration).

# Uninstalling

Deleting the DaemonSet removes the pods, not the agent, which is installed on the nodes:

```bash
kubectl delete -f breeze-host-installer.yaml
```

To remove the agent, run the uninstaller that the installation left on every node. It disables the
scheduled task and deletes `/opt/cloudaware/breeze`:

```bash
sudo sh /opt/cloudaware/breeze/uninstall.sh
```

On Container-Optimized OS nodes the agent is installed elsewhere, and the systemd drop-in the
DaemonSet writes has to go as well:

```bash
sudo sh /var/lib/cloudaware/breeze/uninstall.sh
sudo rm -rf /etc/systemd/system/breeze.service.d
```
