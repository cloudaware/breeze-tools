#!/usr/bin/env sh
#
# Runs the Breeze agent on a schedule inside a container.
#
# Stands in for the cron job or the systemd timer that 'breeze scheduler enable' configures on a
# host, which is why the image build skips that step of breeze/install.sh.

# load the runtime environment, mainly to add the bundled Ruby to the PATH
. "$(dirname "$0")/env.sh"

# minutes between the agent runs, the same interval the cron job uses
interval="${BREEZE_RUN_INTERVAL:-15}"

pid_file="${BREEZE_HOME_DIR}/var/run/breeze.pid"

# pass the termination signal to the agent
trap 'kill -TERM ${agent_pid} 2>/dev/null; exit 0' INT TERM

# fail fast when the container is missing something the agent needs
"$(dirname "$0")/preflight.sh" || exit 1

while :
do
  # an interrupted run leaves the pid file behind and the next run waits for it
  if [ -f "$pid_file" ] && ! kill -0 "$(cat "$pid_file")" 2>/dev/null
  then
    echo "removing the stale pid file ${pid_file}"
    rm -f "$pid_file"
  fi

  # run in the background to keep the signal handler responsive
  breeze run --no-color &
  agent_pid=$!
  wait $agent_pid || echo "the agent exited with a non-zero status"

  sleep $((interval * 60)) &
  wait $!
done
