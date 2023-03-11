FROM alpine

# arguments
ARG log_level=1

# configure breeze agent
COPY ./breeze-agent/ /tmp/breeze-agent/
RUN sed -i "/log_level/s/2/${log_level}/" /tmp/breeze-agent/etc/agent.conf

COPY ./breeze-installer.sh /tmp/breeze-installer.sh

# create breeze user
RUN adduser -D -u 10000 breeze \
    && chown breeze. /tmp/breeze-installer.sh \
    && chmod +x /tmp/breeze-installer.sh

USER breeze

CMD ["/bin/sh", "-c", "/tmp/breeze-installer.sh"]
