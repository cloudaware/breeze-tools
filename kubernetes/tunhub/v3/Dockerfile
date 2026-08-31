# syntax=docker/dockerfile:1
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends pciutils virt-what iproute2 iptables && \
    rm -rf /var/lib/apt/lists/*

# Add Tini
ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# copy the agent runtime and the local gems
COPY ./breeze/runtime/ /opt/cloudaware/breeze/
COPY ./breeze/rubygems/ /tmp/rubygems/

# install the agent gems with the bundled Ruby
RUN set -eux; \
    . /opt/cloudaware/breeze/bin/env.sh; \
    export RUBYGEMS_PREVENT_UPDATE_SUGGESTION=true; \
    (cd /tmp/rubygems; gem install --env-shebang --force --local --no-document cloudaware-breeze-*.gem); \
    rm -rf /tmp/rubygems; \
    breeze version

# the scheduler and the prerequisite checks
COPY ./bin/agent-run.sh /opt/cloudaware/breeze/bin/agent-run.sh
COPY ./bin/preflight.sh /opt/cloudaware/breeze/bin/preflight.sh
COPY ./bin/node-tags.rb /opt/cloudaware/breeze/bin/node-tags.rb
RUN chmod +x /opt/cloudaware/breeze/bin/*.sh

# log to stdout
ENV BREEZE_LOG_FILE=/dev/stdout

# TLS certificates are mounted from Kubernetes secrets at runtime
ENV BREEZE_CLIENT_CERTIFICATE=etc/breeze.crt
ENV BREEZE_CLIENT_PRIVATE_KEY=etc/breeze.key
RUN sed -i -e '/^BREEZE_CLIENT_CERTIFICATE=/d' -e '/^BREEZE_CLIENT_PRIVATE_KEY=/d' /opt/cloudaware/breeze/etc/vars.sh && \
    rm -f /opt/cloudaware/breeze/etc/*.crt /opt/cloudaware/breeze/etc/*.key

ENTRYPOINT ["/tini", "--"]
CMD [ "/opt/cloudaware/breeze/bin/agent-run.sh" ]
