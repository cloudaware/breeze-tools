#!/usr/bin/env sh
#
# Makes the directory the agent is installed in executable.
#
# On Container-Optimized OS the whole stateful partition, /var and /home with it, is mounted
# noexec, so the Ruby of the agent cannot be executed from where it is installed. A bind mount of
# the directory onto itself, remounted without noexec, lifts that for this one directory and
# nothing else.
#
# The mount is a property of the running system, not of the disk, so it is lost at every reboot.
# The DaemonSet re-establishes it when its pod starts, and the systemd unit of the agent runs this
# script as ExecStartPre, so a run that comes before the pod is up is covered as well.
#
# Runs on the node, both from bin/host-install.sh and from the unit. It is idempotent: a directory
# that is already mounted executable is left alone, so it does not stack a mount per agent run.
#
# Invoked as '/bin/sh cos-exec-mount.sh', because the filesystem it lives on is the noexec one it
# is about to fix.

dir="${1:-/var/lib/cloudaware}"

[ -d "$dir" ] || exit 0

# the options of the last mount on this directory, empty when it is not a mount point of its own
options="$(awk -v d="$dir" '$2 == d { o = $4 } END { print o }' /proc/self/mounts)"

case "$options" in
  '')
    # part of the mount of the filesystem around it, give it a mount of its own first
    mount --bind "$dir" "$dir" || exit 1
    ;;
  *noexec*)
    # a mount of its own already, but still carrying the flag
    ;;
  *)
    # already executable
    exit 0
    ;;
esac

mount -o remount,bind,exec "$dir"
