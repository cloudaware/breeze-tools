#!/bin/sh

sh /tmp/breeze-agent/install.sh

while true
do
    # copy Breeze Agent files to the host machine
    if [ ! -d "/opt/breeze-agent" ]
    then
        cp -R /tmp/breeze-agent /opt/breeze-agent
        printf '%s: %s\n' "$(date)" "Breeze-agent folder has been created."
    fi

    printf '%s: %s\n' "$(date)" "Status: OK"
    sleep 3600
done
