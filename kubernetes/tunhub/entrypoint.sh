#!/usr/bin/env bash

ERRORS=0

echo "Checking prerequisites..."

# check if node-tags file on breeze-data volume is mounted for EKS
if $(/opt/breeze-agent/ruby/bin/ruby /opt/breeze-agent/ruby/bin/facter | grep -q 'ec2_instance_id'); then
    echo "Running EKS specific checks..."
    if ! [ -f /breeze-data/node-tags.json ]; then
        echo "ERROR: /breeze-data/node-tags.json is missing; check volume mounts and init-container."
        let ERRORS++
    fi
fi

# check if dev-tun device is present
if ! [ -c /dev/net/tun ]; then
    echo "ERROR: /dev/net/tun device is missing; check volume mounts."
    let ERRORS++
fi

# check if required env vars are present
if ! $(env | grep -q 'BREEZE_RUNTIME=kubernetes' && env | grep -q 'BREEZE_K8S_TUNHUB_CLIENT=enabled'); then
    echo "ERROR: check the required environment variables."
    let ERRORS++
fi

# check tiny init process
if ! $(ps ax | grep -q '[t]ini'); then
    echo "WARNING: 'tini' process is missing."
fi

[[ ERRORS -eq 0 ]] || exit 1

echo "Starting Breeze daemon..."
/opt/breeze-agent/breeze-daemon
