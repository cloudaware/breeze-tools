FROM ubuntu:16.04
ENTRYPOINT /bin/bash
RUN mkdir /etc/cron.d
COPY ./breeze-agent/ /tmp/breeze-agent/
COPY ./breeze-daemon.rb /tmp/breeze-agent/
RUN chmod +x /tmp/breeze-agent/breeze-daemon.rb
