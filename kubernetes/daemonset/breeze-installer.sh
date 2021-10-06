#!/bin/sh

sh /tmp/breeze-agent/install.sh

while true
do
    if [ -f "/var/log/breeze-agent.log" ]; then
        tail -f /var/log/breeze-agent.log | while read line; do echo $line; done
    fi
    sleep 300
done
