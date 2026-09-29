#!/usr/bin/env sh
#
# Installs the Breeze 3 agent on the node this pod runs on.
#
# The container is only a carrier. Every step that touches the node runs in the namespaces of its
# init process through nsenter, so the agent is installed by the stock breeze/install.sh, with the
# Ruby, the package manager and the scheduler of the node, exactly as it would be over SSH.
#
# Needs 'hostPID: true', the SYS_ADMIN capability and an unconfined AppArmor profile to enter those
# namespaces, and a hostPath mount of the directory the agent is installed in, which is the only
# path the container and the node share.
#
# Where that is depends on the node. It is /opt/cloudaware on a general purpose distribution, and
# /var/lib/cloudaware on Container-Optimized OS, whose /opt is part of a read-only root filesystem.
# The manifest has to mount the matching one, breeze-host-installer.yaml and
# breeze-host-installer-cos.yaml do.
#
# Environment:
#   BREEZE_HOST_VARS      lines appended to etc/vars.sh of the agent on the node,
#                         for example BREEZE_VERBOSE=true
#   BREEZE_FORCE_INSTALL  'true' reinstalls even when the node already runs this build

set -e

image_dir='/breeze'
image_marker='/.breeze-daemonset'
vars_block_begin='# BEGIN breeze-daemonset'
vars_block_end='# END breeze-daemonset'
drop_in_dir='/etc/systemd/system/breeze.service.d'
drop_in_file="${drop_in_dir}/10-cos.conf"

echo_info() { printf '[info] %s\n' "$*"; }
echo_error() { printf '[error] %s\n' "$*" >&2; exit 1; }

# runs a command on the node rather than in the container. The mount namespace is what the whole
# installation hangs on; the network namespace matters because the mount namespace brings the
# resolver configuration of the node with it, which on a node running a stub resolver points at an
# address that answers in the network namespace of the node and nowhere else; the rest keeps the
# installer in the environment a host installation runs in.
on_host() {
  nsenter --target 1 --mount --uts --ipc --net --pid -- "$@"
}

# runs a shell command on the node. Everything goes through 'sh' rather than through a binary of
# its own, because 'sh' is the one thing the installation needs the node to have anyway.
on_host_sh() {
  on_host sh -c "$1"
}

[ "$(id -u)" = '0' ] || echo_error 'run the container as root'

# Entering the namespaces of another process needs the SYS_ADMIN capability and, on a node that
# enforces AppArmor, an unconfined profile: the default profile of the container runtime denies a
# confined process the ptrace read of the unconfined init process of the node, so nsenter fails
# whatever capabilities the container was given. Measured on GKE, Container-Optimized OS: with
# SYS_ADMIN and SYS_PTRACE alone nsenter fails, with securityContext.appArmorProfile Unconfined
# added it succeeds.
if ! nsenter_error="$(on_host_sh ':' 2>&1)"
then
  echo_error "the namespaces of the node cannot be entered: ${nsenter_error:-no error reported}. The pod needs the SYS_ADMIN capability, hostPID, and an unconfined AppArmor profile on a node that enforces AppArmor"
fi

# with hostPID the container sees the init process of the node as PID 1. Without it PID 1 is the
# container itself, nsenter still succeeds, and the installation would silently land in the
# container instead of on the node.
if on_host_sh "test -e ${image_marker}"
then
  echo_error 'PID 1 is the container rather than the node, the pod needs hostPID: true'
fi

# The node decides where the agent goes. On Container-Optimized OS /opt is part of the read-only
# root filesystem, so the agent goes to the stateful partition, which is writable but mounted
# noexec, see bin/cos-exec-mount.sh.
node_os="$(on_host_sh '. /etc/os-release 2>/dev/null; echo "${ID}"')"
case "$node_os" in
  cos) parent_dir='/var/lib/cloudaware' ;;
    *) parent_dir='/opt/cloudaware' ;;
esac

destination_dir="${parent_dir}/breeze"
staging_dir="${parent_dir}/breeze-installer"
install_log="${staging_dir}/install.log"
vars_file="${destination_dir}/etc/vars.sh"

echo_info "the node runs '${node_os:-unknown}', installing into ${destination_dir}"

# The directory is created on the node and then looked for in the container, which is the only way
# to tell a hostPath mount from a directory of the container's own filesystem. Without this an
# unmounted or mismatched manifest would install into the container that is about to be discarded,
# report success, and leave the node without an agent.
mount_probe="${parent_dir}/.breeze-mount-probe"
on_host_sh "mkdir -p ${parent_dir} && : > ${mount_probe}"
if [ ! -f "$mount_probe" ]
then
  on_host_sh "rm -f ${mount_probe}"
  echo_error "${parent_dir} of the node is not mounted into the container, this node needs the manifest that mounts it: breeze-host-installer-cos.yaml on Container-Optimized OS, breeze-host-installer.yaml otherwise"
fi
rm -f "$mount_probe"

# The certificate and the key are mounted from a secret over the installer of the image. Without
# them the agent installs and then fails at every run on the node, where the failure is far less
# visible than it is here. The paths are the ones etc/vars.sh names, so that an image that carries
# its own certificates is checked just as well.
for setting in BREEZE_CLIENT_CERTIFICATE BREEZE_CLIENT_PRIVATE_KEY
do
  value="$(sed -n "s/^${setting}=//p" "${image_dir}/runtime/etc/vars.sh" | tail -n 1)"
  [ -n "$value" ] || echo_error "${setting} is not set in etc/vars.sh of the image"
  case "$value" in
    /*) file="$value" ;;
     *) file="${image_dir}/runtime/${value}" ;;
  esac
  [ -r "$file" ] || echo_error "${file} is not readable, check the breeze-tls-secret secret and the volume mounts"
done

# The installer is staged on the node because the filesystem of the image is not visible in the
# mount namespace of the node. What is written here is written on the node, through the hostPath
# mount.
echo_info "staging the installer in ${staging_dir}"
rm -rf "$staging_dir"
mkdir -p "$staging_dir"
cp -a "${image_dir}/." "${staging_dir}/"

# The home directory of the agent is hardcoded in three places of the installer, so a node that
# cannot use /opt needs all three rewritten before the installer runs. The result is checked rather
# than assumed: a future installer that spells these differently must fail here, loudly, instead of
# installing into a read-only /opt.
if [ "$parent_dir" != '/opt/cloudaware' ]
then
  echo_info "relocating the agent to ${destination_dir}"
  sed -i "s|^export BREEZE_HOME_DIR=.*|export BREEZE_HOME_DIR=\"${destination_dir}\"|" "${staging_dir}/runtime/bin/env.sh"
  sed -i "s|^destination_dir=.*|destination_dir='${destination_dir}'|" "${staging_dir}/install.sh"
  sed -i "s|^destination_dir=.*|destination_dir='${destination_dir}'|" "${staging_dir}/runtime/uninstall.sh"
  for file in runtime/bin/env.sh install.sh runtime/uninstall.sh
  do
    grep -q "$destination_dir" "${staging_dir}/${file}" ||
      echo_error "${file} of the installer does not set the home directory where it used to, the relocation would leave the agent pointing at /opt"
  done
fi

# On a noexec stateful partition nothing below can run the Ruby of the agent until this is done,
# the gem installation of the installer included.
if [ "$node_os" = 'cos' ]
then
  echo_info "making ${parent_dir} executable on the node"
  on_host_sh "sh ${staging_dir}/runtime/bin/cos-exec-mount.sh ${parent_dir}" ||
    echo_error "${parent_dir} could not be remounted executable on the node"
fi

build="$(cat "${staging_dir}/runtime/.build")"
installed_build="$(cat "${destination_dir}/.build" 2>/dev/null || true)"

if [ "$BREEZE_FORCE_INSTALL" != 'true' ] &&
   [ -n "$installed_build" ] && [ "$installed_build" = "$build" ] &&
   [ -f "${destination_dir}/bin/env.sh" ]
then
  echo_info "the node already runs build ${build}, skipping the installation"
else
  echo_info "installing build ${build} on the node"

  # the installer copies the runtime file by file with 'cp -v', which is thousands of lines in
  # 'kubectl logs'. They are kept in the log file, which stays on the node when the installer
  # fails, and printed in full when it does.
  if on_host sh "${staging_dir}/install.sh" > "$install_log" 2>&1
  then
    grep -v "' -> '" "$install_log" || true
  else
    cat "$install_log"
    echo_error "the installer failed on the node, its output is in ${install_log}"
  fi
fi

# mirrors Breeze::Scheduler.status in the agent gem, which reports the scheduler as enabled when
# one of these files exists
scheduler_configured() {
  on_host_sh '[ -f /etc/systemd/system/breeze.timer ] || [ -f /etc/cron.d/breeze ]'
}

# An installation that was skipped can still be left without a schedule: on Container-Optimized OS
# /etc is an overlay whose upper layer is a tmpfs, so every reboot takes the systemd units with it
# while the agent itself, on the stateful partition, survives. Enabling the scheduler again is
# cheap and is what makes the node recover from a reboot without reinstalling anything.
if ! scheduler_configured
then
  echo_info 'enabling the scheduled task on the node'
  on_host_sh ". ${destination_dir}/bin/env.sh && breeze scheduler enable --no-color"
fi

# The unit the agent writes names /opt and does not know about the noexec mount, so a drop-in
# replaces the command and re-establishes the mount before every run. It is rewritten on every pod
# start because it lives in the same /etc that the reboot cleared.
if [ "$node_os" = 'cos' ]
then
  echo_info "writing ${drop_in_file} on the node"
  on_host_sh "mkdir -p ${drop_in_dir} && { \
    echo '# Written by the Breeze DaemonSet, see breeze-host-installer-cos.yaml.'; \
    echo '# The agent lives on the stateful partition, which is mounted noexec, and the unit of'; \
    echo '# the agent names /opt, which is read-only on this node.'; \
    echo '[Service]'; \
    echo 'ExecStartPre=/bin/sh ${destination_dir}/bin/cos-exec-mount.sh ${parent_dir}'; \
    echo 'ExecStart='; \
    echo 'ExecStart=/bin/sh ${destination_dir}/bin/scheduled-task.sh'; \
  } > ${drop_in_file} && systemctl daemon-reload && systemctl restart breeze.timer"
fi

# What the DaemonSet writes into the configuration of the agent: what the node needs, and then
# BREEZE_HOST_VARS, which comes last so that it can override any of it.
host_vars=''

if [ "$node_os" = 'cos' ]
then
  # The scheduled task runs as root, whose home directory is on the read-only root filesystem here.
  # The rubygems plugin shells out to 'gem', which creates its specification cache under ~/.cache
  # and fails with EROFS before it does anything else, so the agent reports with that plugin
  # failing at every run. Measured on a GKE COS node: three failed 'gem' calls per run before this,
  # none after.
  mkdir -p "${destination_dir}/var/home"
  host_vars="HOME=${destination_dir}/var/home"
fi

if [ -n "$BREEZE_HOST_VARS" ]
then
  if [ -n "$host_vars" ]
  then
    host_vars="$(printf '%s\n%s' "$host_vars" "$BREEZE_HOST_VARS")"
  else
    host_vars="$BREEZE_HOST_VARS"
  fi
fi

# the installer rewrites vars.sh on every install, and an install that was skipped leaves the block
# of the previous pod behind, so the block is replaced rather than appended to. The file is on the
# hostPath mount, so this needs no nsenter.
if [ -n "$host_vars" ]
then
  echo_info "writing the settings of the DaemonSet to ${vars_file}"
  sed -i "/^${vars_block_begin}\$/,/^${vars_block_end}\$/d" "$vars_file"
  {
    echo "$vars_block_begin"
    printf '%s\n' "$host_vars"
    echo "$vars_block_end"
  } >> "$vars_file"
fi

# the agent runs on the node, with the libraries of the node, so it is the node that has to be able
# to start it. A missing runtime dependency is reported here, where the pod shows it, instead of at
# the first run of the timer, where only the node shows it.
echo_info 'verifying the installation'
on_host_sh ". ${destination_dir}/bin/env.sh && breeze version && breeze scheduler status --no-color"

echo_info "removing ${staging_dir}"
rm -rf "$staging_dir"

echo_info 'the agent is installed on the node, the first run follows within 15 minutes'
