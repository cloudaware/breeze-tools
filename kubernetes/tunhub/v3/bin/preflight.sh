#!/usr/bin/env sh
#
# Checks the container prerequisites before the Breeze agent starts.
#
# Baked into the image, so every platform manifest shares one implementation. The platform
# differences come from the environment and from what the manifest mounts, not from a per-platform
# copy of this script:
#
#   BREEZE_K8S_CREATE_TUN_DEVICE=true   create /dev/net/tun instead of expecting a hostPath mount,
#                                       for GKE Autopilot; requires a container running as root
#   /breeze-data mounted                collect the EC2 tags of the node into it, for EKS; skipped
#                                       when BREEZE_K8S_EKS_CLUSTER_ARN names the cluster already
#
# Called by bin/agent-run.sh before its first run. Can also be run on its own:
#
#   kubectl exec deployment/breeze -- /opt/cloudaware/breeze/bin/preflight.sh

# load the runtime environment, this script may be called directly
. "$(dirname "$0")/env.sh"

errors=0

error() {
  echo "ERROR: $*"
  errors=$((errors + 1))
}

warning() {
  echo "WARNING: $*"
}

# Resolves a path that the agent takes relative to its home directory
# $1: path, absolute or relative to BREEZE_HOME_DIR
resolve_path() {
  case "$1" in
    /*) echo "$1" ;;
     *) echo "${BREEZE_HOME_DIR}/$1" ;;
  esac
}

echo "Checking prerequisites..."

# the tunnel device, created here when the platform does not allow a hostPath mount
if [ "$BREEZE_K8S_CREATE_TUN_DEVICE" = 'true' ] && [ ! -c /dev/net/tun ]
then
  if [ "$(id -u)" = '0' ]
  then
    echo "creating /dev/net/tun"
    mkdir -p /dev/net && mknod /dev/net/tun c 10 200 && chmod 600 /dev/net/tun
  else
    error "BREEZE_K8S_CREATE_TUN_DEVICE is set, but the container does not run as root"
  fi
fi

if [ ! -c /dev/net/tun ]
then
  error "/dev/net/tun is missing; mount the device or set BREEZE_K8S_CREATE_TUN_DEVICE=true"
fi

# the netfilter binary the tunhub plugin runs, which needs the capabilities of its backend. The
# default backend differs between distribution releases, so check the one that will actually run
# rather than assume which of the two it is.
if ! iptables -L -n >/dev/null 2>&1
then
  error "$(command -v iptables) cannot read the rule set; check the file capabilities of its backend"
fi

# the variables the server needs to broker the tunnel, see facts.d/k8s.rb in the agent gem
if [ "$BREEZE_RUNTIME" != 'kubernetes' ]
then
  error "BREEZE_RUNTIME is '${BREEZE_RUNTIME}', expected 'kubernetes'"
fi

if [ "$BREEZE_K8S_TUNHUB_CLIENT" != 'enabled' ]
then
  error "BREEZE_K8S_TUNHUB_CLIENT is '${BREEZE_K8S_TUNHUB_CLIENT}', expected 'enabled'"
fi

# the client certificate, mounted from a secret unless it was baked into the image
for file in "$(resolve_path "$BREEZE_CLIENT_CERTIFICATE")" "$(resolve_path "$BREEZE_CLIENT_PRIVATE_KEY")"
do
  if [ ! -r "$file" ]
  then
    error "${file} is not readable; check the secret and the volume mounts"
  fi
done

# the node tags carry the EKS cluster name, see facts.d/k8s.rb in the agent gem. The directory the
# agent reads them from exists only when the manifest declares it, so this step enables itself on
# EKS and stays quiet everywhere else, and an explicit cluster ARN makes the tags unnecessary.
if [ -d /breeze-data ] && [ -z "$BREEZE_K8S_EKS_CLUSTER_ARN" ]
then
  # fatal on purpose: without the cluster name the agent resolves an instance identity instead of
  # the cluster and reports under the wrong agent id, which is worse than not reporting at all
  ruby "$(dirname "$0")/node-tags.rb"
  case $? in
    0) ;;
    2) error "the node tags do not name the cluster, the agent would not identify itself as the EKS cluster" ;;
    *) error "the node tags were not collected, the agent would not identify itself as the EKS cluster" ;;
  esac
fi

# tini reaps the processes the tunhub plugin leaves behind
case "$(tr '\0' ' ' < /proc/1/cmdline 2>/dev/null)" in
  *tini*) ;;
       *) warning "tini is not PID 1, orphaned processes will not be reaped" ;;
esac

if [ "$errors" -gt 0 ]
then
  echo "prerequisite checks failed with ${errors} error(s)"
  exit 1
fi

echo "prerequisite checks passed"
