FROM alpine

# arguments
ARG log_level=1

# configure breeze agent
COPY ./breeze-agent/ /tmp/breeze-agent/
RUN sed -i "/log_level/s/2/${log_level}/" /tmp/breeze-agent/etc/agent.conf

CMD ["/scripts/init-entrypoint.sh"]
