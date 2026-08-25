# Zephyr Freestanding Application Workspace Example

A basic Zephyr RTOS "Hello World" application configured for STM32 Nucleo-G474RE and showcasing a freestanding application structure.

## Overview

This project demonstrates:
- Freestanding application structure linking to the central Zephyr source tree via `zephyrproject` symbolic link.
- Docker container configuration for development and debugging.

## Environment Setup
- Make sure [zephyrproject](zephyrproject) symbolic link points to an existing folder.
    - Symbolic link used to avoid duplicating the Zephyr source tree in different workspaces.
    - If using Docker, see the [container configuration](.devcontainer/devcontainer.json).

- Working example: _(assuming west.yml referres to Zephyr v4.4.2 and the Zephyr source trees are located in `/opt/zephyrproject-rtos/<version>`)_
```Shell
> ln -sfn /opt/zephyrproject-rtos/v4.4.2 zephyrproject # Non-existent target folder
> file zephyrproject # Verifying broken link
zephyrproject: broken symbolic link to /opt/zephyrproject-rtos/v4.4.2
> mkdir -p /opt/zephyrproject-rtos/v4.4.2 # Create target folder
> file zephyrproject # Verifying proper link
zephyrproject: symbolic link to /opt/zephyrproject-rtos/v4.4.2
```

- Run `west update` to fetch the Zephyr source tree and update the modules.
    - This might take a while depending on your internet connection and the number of modules to update. See [west.yml](sample-zephyr-app/west.yml) for the list of modules.
    - We don't need to run `west init --local sample-zephyr-app` because the workspace is already initialized. See [.west/config](.west/config) for the configuration.

- Run `west zephyr-export` to registers the current Zephyr installation to the [CMake user package registry](~/.cmake/packages/).

- Check if [zephyrproject/.west/config](zephyrproject/.west/config) exists and contains the following:
```ini
[manifest]
path = zephyr
file = west.yml

[zephyr]
base = zephyr
```
    - This is required to avoid compilation errors when building the application. _(I couldn't discover the root cause of this issue, but it seems to be related to the Zephyr version and the way the workspace is structured.)_

## Building and Running
- Build for ST Nucleo G474RE `west build -b nucleo_g474re sample-zephyr-app -d build --pristine`
- Flash to ST Nucleo G474RE `west flash -d build`

## Debugging

VS Code launch configurations are provided in `.vscode/launch.json`:
- **Debug with OpenOCD (Nucleo G474RE)**: Launches OpenOCD and connects GDB to the board via ST-Link.
- **Attach to OpenOCD Server**: Connects GDB to a running OpenOCD instance on port 3333.
