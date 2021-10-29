# Overview

This document describes how to create a Breeze Agent Deployment via AWS Systems Manager Distributor.

# How it works

The user creates a package with Breeze Agent. The distributor publishes this package to System Manager managed instances. Then the agent can be installed or uninstalled:
* one time by using [AWS Systems Manager Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/execute-remote-commands.html)
* on a schedule using [AWS Systems Manager State Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state.html)

# Prerequisites

The distributor package consists of a manifest and two archive files for Windows and Linux platforms. Each archive contains install and uninstall scripts, as well as Breeze Agent distro respectively to the platform.

The manifest template and scripts can be obtained from [Github repository](https://github.com/cloudaware/breeze-tools/tree/master/AWS-SSM)

The repository structure:
* [`manifest.json`](https://raw.githubusercontent.com/cloudaware/breeze-tools/master/AWS-SSM/manifest.json) - the manifest template
  * `linux` - scripts for Linux platform
    * [`install.sh`](https://raw.githubusercontent.com/cloudaware/breeze-tools/master/AWS-SSM/linux/install.sh)
    * [`uninstall.sh`](https://raw.githubusercontent.com/cloudaware/breeze-tools/master/AWS-SSM/linux/uninstall.sh)
  * `windows` - scripts for Windows platform
    * [`install.ps1`](https://raw.githubusercontent.com/cloudaware/breeze-tools/master/AWS-SSM/windows/install.ps1)
    * [`uninstall.ps1`](https://raw.githubusercontent.com/cloudaware/breeze-tools/master/AWS-SSM/windows/uninstall.ps1)

The Breeze Agent distro files can be obtained from the [CMDB](https://docs.cloudaware.com/DOCS/Breeze---Installation.1206419783.html#Breeze-Installation-Navigation).

# Preparing package files

## Archive for Linux platform

Archive consists of the following files:
- `install.sh`
- `uninstall.sh`
- `agent.XXX.YY.Z.x86_64.linux.tgz` (the Linux Breeze Agent distro as it was downloaded from CMDB)

Ensure that the `.sh` files have the correct line breaks, namely `LF` (`\n` == `0x0A`).

Pack the files mentioned above to the `.zip` archive named `breeze-agent-linux.zip`.

## Archive for Windows platform

Archive consists of the following files:
- `install.ps1`
- `uninstall.ps1`
- `agent.XXX.YY.Z.windows.signed.exe` (the Windows Breeze Agent distro as it was downloaded from CMDB)

Ensure that the `.ps1` files have the correct line breaks, namely `CRLF` (`\r\n` == `0x0D 0x0A`).

Pack the files mentioned above to the `.zip` archive named `breeze-agent-windows.zip`.

## Calculate checksums

Calculate and note the `sha256` checksums of the each created `.zip` archive, it will be used at the next steps. In order to do this the following commands can be used:
### On Linux
```console
shasum -a 256 file-name.zip
```
or
```console
openssl dgst -sha256 file-name.zip
```
### On Windows
```ps
Get-FileHash -Path file-name.zip
```

## Manifest

In the `manifest.json` find the field `"version"` and change its value to something meaningful. This is also the value of Version name that should be specified when the package will be added to the Distributor (it becomes part of the AWS Systems Manager document). A version value can contain letters, numbers, underscores, hyphens, and periods, and be from 3 to 128 characters in length. It is recommended to use a human-readable value.

Then find the section `"files"` section and replace each `ARCHIVE_CHECKSUM` placeholder with the checksums calculated for the `.zip` archive files.

# Create Distributor package

In the AWS Systems Manager create an `Advanced` package as described in [AWS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/distributor-working-with-packages-create.html).
