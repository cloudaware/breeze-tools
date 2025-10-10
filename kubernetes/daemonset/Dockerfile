# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 alpine
ARG log_level=1
COPY ./breeze-agent/ /tmp/breeze-agent/
RUN sed -i "/log_level/s/2/${log_level}/" /tmp/breeze-agent/etc/agent.conf
