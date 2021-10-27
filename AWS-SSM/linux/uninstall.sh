#!/bin/bash
echo 'Uninstalling Breeze Agent...'
rm -f /etc/cron.d/breeze-agent
rm -f /etc/cron.d/breeze-agent-logrotate
rm -f /var/log/breeze-agent.log
rm -fR /opt/breeze-agent
echo 'Done'
