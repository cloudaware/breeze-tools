#!/bin/bash
echo 'Installing Breeze Agent...'
tar xf `ls *.linux.tgz | head -n 1`
cd breeze-agent
./install.sh
cd ..
rm -fR breeze-agent
echo 'Done'
