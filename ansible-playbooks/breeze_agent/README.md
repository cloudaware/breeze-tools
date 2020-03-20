breeze_agent
---

1. Put breeze agent installation files to the 'files' directory.
2. Specify installation file name and hosts in 'breeze_agent_linux.yml' and 'breeze_agent_windows.yml'

```
- hosts: linux
  vars:
    linux_agent: linux-breeze-agent.tgz
```
