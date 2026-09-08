# Zephyr Freestanding Application Workspace Example

A basic Zephyr RTOS "Hello World" application configured for STM32 Nucleo-G474RE showcasing a freestanding application structure.

## Overview

This project demonstrates:
- Freestanding application structure pointing to a central or local Zephyr source tree via the `ZEPHYR_BASE` environment variable.
- Portable environment setup via [env.sh](env.sh) suitable for local development, containers, and CI/CD pipelines.
- Docker Dev Container configuration for development and debugging.

## Prerequisites

For the dev container path you need:

- **Docker Engine 18.06 or newer**, installed from Docker's own repositories, or Docker Desktop. On Ubuntu the `docker` snap package is **not** supported by the Dev Containers extension.
- **Your user in the `docker` group** on Linux: `sudo usermod -aG docker $USER`, then log out and back in.
- **VS Code** with the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).
- **Disk space.** This is a large image. The figures below are measured, not estimated, for Zephyr v4.4.2 on a linux/amd64 host.

| What | Size |
| --- | --- |
| Base image download | 7.7 GB compressed (amd64) |
| Base image unpacked | 31.8 GB |
| Image after this repo's Dockerfile and features | 33.4 GB |
| Shared Zephyr volume, per version | ~2.7 GB |

Budget roughly **40 GB free** for the image plus one Zephyr version, and another ~2.7 GB for each additional version you keep in the volume. On Docker Desktop the virtual disk has its own limit, configured under **Settings → Resources**; raise it before the first build if it is smaller than that.

Most of the image is the Zephyr SDK: 13 GB covering 35 target toolchains, of which this application uses one (`arm-zephyr-eabi`, 761 MB) plus the host tools (1.2 GB). Nothing in this repository needs the rest, so a slimmer project-specific image is an option if the size becomes a problem.

## Dev Container Setup

Open this repository in VS Code and select **Dev Containers: Reopen in Container**.

Creating the container does two slow things in sequence: it pulls the image, then it runs [.devcontainer/setup-zephyr.sh](.devcontainer/setup-zephyr.sh), which clones Zephyr and the configured modules into the shared volume. On a cold host that is roughly 9 GB over the network, so expect to wait. A host where another dev container already populated the volume skips the clone. To watch progress, or to read the error if creation fails, run **Dev Containers: Show Container Log** from the command palette.

Inside the container, `/opt/zephyrproject-rtos` is the Docker named volume `zephyrproject-rtos` (declared in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)). Each Zephyr version gets its own west workspace in a subdirectory, e.g. `/opt/zephyrproject-rtos/v4.4.2`. The volume persists across container rebuilds and is shared by every dev container on this host that mounts it, so a version fetched once is available to all of them.

On every container creation, [.devcontainer/setup-zephyr.sh](.devcontainer/setup-zephyr.sh) runs as `postCreateCommand`. It sources [env.sh](env.sh) and then:
1. Runs `west init` for `${ZEPHYR_VERSION}` only if no west workspace exists yet at `${ZEPHYR_WORKSPACE}`. An existing checkout in the volume is reused as-is.
2. Runs `west update` for the application's module dependencies, so they match the manifest revision.
3. Runs `west zephyr-export`, which writes to the container's home directory and therefore has to be redone after every rebuild.

To pick another Zephyr version, change the `ZEPHYR_VERSION` default in [env.sh](env.sh) and rebuild the container; a version not yet present in the volume is fetched on first creation.

> Removing the volume deletes every Zephyr version stored in it. The next container creation downloads the configured version again.

## Native Environment Setup

The steps below are what the dev container setup script automates. Use them when developing directly on the host or in CI.

### 1. Configure Environment Variables
Source the [env.sh](env.sh) script to set default environment variables:

```bash
source env.sh
```

This sets the following default variables (which can be overridden prior to sourcing):
- `ZEPHYR_VERSION` _(default: `v4.4.2`)_
- `ZEPHYR_WORKSPACE` _(default: `/opt/zephyrproject-rtos/${ZEPHYR_VERSION}`)_
- `ZEPHYR_BASE` _(default: `${ZEPHYR_WORKSPACE}/zephyr`)_
- `ZEPHYR_APP_DEPS` _(default: `"cmsis_6 hal_stm32"`)_

To use custom paths on your local machine or in CI/CD, simply override them:
```bash
ZEPHYR_VERSION=v4.3.1; ZEPHYR_WORKSPACE=~/zephyrproject; source env.sh
```

### 2. Initialize Zephyr Source Tree (if not already present)
If the west workspace is not yet initialized at `${ZEPHYR_WORKSPACE}`, run:

```bash
west init \
    --manifest-url https://github.com/zephyrproject-rtos/zephyr \
    --manifest-rev "${ZEPHYR_VERSION}" \
    "${ZEPHYR_WORKSPACE}"
```

### 3. Update Application Dependencies
Fetch/update the specific modules required by the application:

```bash
(
    cd "${ZEPHYR_WORKSPACE}" && west update "${ZEPHYR_APP_DEPS[@]}"
)
```

### 4. Register Zephyr with CMake
Register the Zephyr installation to the CMake user package registry:

```bash
(
    cd "${ZEPHYR_WORKSPACE}" && west zephyr-export
)
```

This registry entry lets CMake locate Zephyr without relying on `ZEPHYR_BASE`. The application's `CMakeLists.txt` also uses `ZEPHYR_BASE` as a direct hint when it is set.

## Building and Running

- **Build for ST Nucleo G474RE:**
  ```bash
  west build -b nucleo_g474re sample-zephyr-app -d build --pristine
  ```

- Another option is to use CMake directly, if you successfully exported Zephyr to the CMake user package registry:
  ```bash
  cmake -B build -DBOARD=nucleo_g474re -S sample-zephyr-app
  cmake --build build
  ```

- **Flash to ST Nucleo G474RE:**
  ```bash
  west flash -d build
  ```

## Debugging

VS Code launch configurations are provided in [.vscode/launch.json](.vscode/launch.json):
- **Debug with OpenOCD (Nucleo G474RE)**: Launches OpenOCD and connects GDB to the board via ST-Link.
- **Attach to OpenOCD Server**: Connects GDB to a running OpenOCD instance on port 3333.

## AI Tools

### Claude Code in the Dev Container
Claude Code is installed through the official [Dev Container Feature](https://code.claude.com/docs/en/devcontainer), which also adds the Claude Code VS Code extension. The CLI auto-updates itself inside the container.

- On first use, open a terminal in the container, run `claude`, and follow the browser sign-in prompt. If the browser finishes but the terminal does not notice, paste the code shown in the browser at the `Paste code here if prompted` prompt.
- Authentication and settings live in the Docker named volume `claude-code-config`, mounted at `/home/user/.claude` with `CLAUDE_CONFIG_DIR` pointing at it. The volume is shared by every dev container on this host that mounts it, so you sign in once per host and stay signed in across rebuilds. To start over, sign out with `/logout` or run `docker volume rm claude-code-config`.

> The volume holds your Claude Code credentials. Anything running inside the container, including `claude --dangerously-skip-permissions`, can read them.