# syntax=docker/dockerfile:1
FROM alpine:3

# the container never runs the agent, it carries the installer to the node and runs it there with
# nsenter, which Alpine provides through busybox

# tells the installer apart from the node, see bin/host-install.sh
RUN touch /.breeze-daemonset

# the agent installer, unpacked next to this Dockerfile, is copied to the node as it is
COPY ./breeze/ /breeze/

# the certificates are mounted from a Kubernetes secret under fixed names, because the installer
# names them after the Breeze id, which a generic manifest cannot mount
RUN sed -i -e '/^BREEZE_CLIENT_CERTIFICATE=/d' -e '/^BREEZE_CLIENT_PRIVATE_KEY=/d' /breeze/runtime/etc/vars.sh && \
    rm -f /breeze/runtime/etc/*.crt /breeze/runtime/etc/*.key && \
    printf 'BREEZE_CLIENT_CERTIFICATE=etc/breeze.crt\nBREEZE_CLIENT_PRIVATE_KEY=etc/breeze.key\n' >> /breeze/runtime/etc/vars.sh

# installed on the node with the rest of the runtime, and run from the systemd unit of the agent,
# see bin/cos-exec-mount.sh
COPY ./bin/cos-exec-mount.sh /breeze/runtime/bin/cos-exec-mount.sh
RUN chmod +x /breeze/runtime/bin/cos-exec-mount.sh

COPY ./bin/host-install.sh ./bin/host-logger.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/host-install.sh /usr/local/bin/host-logger.sh

CMD ["/usr/local/bin/host-logger.sh"]
