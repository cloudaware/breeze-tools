#!/usr/bin/env sh
#
# Streams the agent log of the node into the container stdout, so that 'kubectl logs' shows the
# runs of an agent that is not running in this pod at all.
#
# The log is written by /opt/cloudaware/breeze/bin/scheduled-task.sh on the node and reaches this
# container through the hostPath mount of /opt.

log_file="${BREEZE_HOST_LOG_FILE:-/opt/cloudaware/breeze/var/log/breeze.log}"

# the file appears with the first run of the agent, up to 15 minutes after the installation
while [ ! -f "$log_file" ]
do
  echo "waiting for ${log_file}"
  sleep 30
done

# -F follows the file through the rotation or the truncation it may be subject to on the node
exec tail -n +1 -F "$log_file"
