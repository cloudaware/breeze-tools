breeze_agent
---

1. Put Puppet module `breeze_agent` to the `/etc/puppetlabs/code/environments/production/modules/`.
2. Put breeze agent installation files to the `/etc/puppetlabs/code/environments/production/modules/breeze_agent/files` directory.
3. Attach `breeze_agent` class to the necessary group in the Puppet Dashboard.
4. Add required variables `breeze_package_linux` and `breeze_package_windows`.
