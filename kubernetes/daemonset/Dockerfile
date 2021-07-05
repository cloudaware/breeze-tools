FROM ubuntu:20.04

# arguments
ARG log_level=1

# install required packages
RUN apt-get update && \
    apt-get install -y pciutils virt-what && \
    rm -rf /var/lib/apt/lists/*

# Add Tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tmp/tini
RUN chmod +x /tmp/tini
ENTRYPOINT ["/tmp/tini", "--"]

# configure breeze agent
COPY ./breeze-agent/ /tmp/breeze-agent/
COPY ./bin/breeze-daemon /tmp/breeze-agent/
RUN sed -i "/log_level/s/2/${log_level}/" /tmp/breeze-agent/etc/agent.conf

CMD [ "/tmp/breeze-agent/breeze-daemon" ]
