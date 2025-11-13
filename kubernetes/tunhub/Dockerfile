# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 ubuntu:20.04

# arguments
ARG log_level=1

# install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends pciutils virt-what iptables openvpn && \
    rm -rf /var/lib/apt/lists/*

# Add Tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# configure breeze agent
COPY ./breeze-agent/ /opt/breeze-agent/
COPY ./bin/breeze-daemon /opt/breeze-agent
RUN sed -i "/log_level/s/2/${log_level}/" /opt/breeze-agent/etc/agent.conf

# add linux capabilities
RUN setcap cap_net_admin+ep /usr/sbin/openvpn \
    && setcap cap_net_admin,cap_net_raw+ep /usr/sbin/xtables-legacy-multi \
    && chmod u+s /bin/ip

# create breeze user
RUN useradd --uid 10000 breeze \
    && chown -R breeze. /opt/breeze-agent/ \
    && chown breeze /run

USER 10000

ENTRYPOINT ["/tini", "--"]
CMD [ "/opt/breeze-agent/breeze-daemon" ]
