# Zephyr Freestanding Application Workspace Example

A basic Zephyr RTOS "Hello World" application configured for STM32 Nucleo-G474RE showcasing a freestanding application structure.

## Overview

This project demonstrates:
- Freestanding application structure pointing to a shared Zephyr source tree via the `ZEPHYR_BASE` environment variable.
- A single place, [env.sh](env.sh), where the Zephyr version and the application's module dependencies are declared.
- Docker Dev Container configuration for development and debugging.

> **The dev container is the only supported environment.** Everything the build needs, west, CMake, Ninja, Python packages and the Zephyr SDK, comes from the container image rather than from this repository, so the commands below will not work on a bare host. If you want a host installation anyway, follow Zephyr's own [Getting Started Guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html); this repository does not document or test that path.

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
1. Runs `west init` for `${ZEPHYR_VERSION}` unless `${ZEPHYR_WORKSPACE}/.west/config` already exists, which is the file west writes only once initialization has succeeded. A complete checkout in the volume is reused as-is. A workspace left half-built by an interrupted or failed earlier attempt is repaired instead of being mistaken for a good one: if the Zephyr clone survived, only the missing configuration is recreated, with no re-download. Setup holds a lock on the workspace for the duration, so two containers created at the same time take turns rather than racing.
2. Runs `west update` for the application's module dependencies, so they match the manifest revision.
3. Runs `west zephyr-export`, which writes to the container's home directory and therefore has to be redone after every rebuild. The resulting registry entry lets CMake locate Zephyr without relying on `ZEPHYR_BASE`, which is what makes the CMake preset route below work. The application's `CMakeLists.txt` also uses `ZEPHYR_BASE` as a direct hint when it is set.

> Removing the volume deletes every Zephyr version stored in it. The next container creation downloads the configured version again.

### Environment variables

[env.sh](env.sh) is the single source of truth for which Zephyr the container builds against. It is sourced by the setup and verification scripts, and it defines:

| Variable | Default |
| --- | --- |
| `ZEPHYR_VERSION` | `v4.4.2` |
| `ZEPHYR_WORKSPACE` | `/opt/zephyrproject-rtos/${ZEPHYR_VERSION}` |
| `ZEPHYR_BASE` | `${ZEPHYR_WORKSPACE}/zephyr` |
| `ZEPHYR_APP_DEPS` | `cmsis_6 hal_stm32` |

To target another Zephyr version, change the `ZEPHYR_VERSION` default and rebuild the container; a version not yet present in the volume is fetched on first creation. To add a module dependency, add it to `ZEPHYR_APP_DEPS` and rebuild, or fetch it in place with `west update <module>` from `${ZEPHYR_WORKSPACE}`.

A container terminal does not have these variables set, so run `source env.sh` before using `west` in a shell you opened yourself.

### Shared tree verification

Because the volume is mounted read-write and shared, another project on the same host can leave the tree in a state this project does not expect: a different ref checked out, an edit made in place, or a module off its manifest revision. None of that announces itself, and all of it changes what you build.

On every container start, [.devcontainer/verify-zephyr.sh](.devcontainer/verify-zephyr.sh) runs as `postStartCommand` and checks that the tree still matches `${ZEPHYR_VERSION}`'s manifest. It verifies that the west workspace is fully initialized, that Zephyr sits at the expected tag with a detached `HEAD` and no local modifications, that every module in `ZEPHYR_APP_DEPS` is cloned, and that `west compare` reports no revision drift in any project. Modules other projects need but this one does not are ignored, so projects may declare different dependency sets.

The script only reads. It repairs nothing and names the problem instead, because the tree is shared and the right fix depends on why it changed. A failure shows an error notification in VS Code and leaves the container usable so you can investigate. You can run it by hand at any time:

```bash
bash .devcontainer/verify-zephyr.sh
```

## Building and Running

Run these in a container terminal, from the repository root. Both routes write to `build/<preset>`, matching the `binaryDir` in [sample-zephyr-app/CMakePresets.json](sample-zephyr-app/CMakePresets.json), so one board never overwrites another's build tree.

- **Build for ST Nucleo G474RE:**
  ```bash
  west build --board nucleo_g474re sample-zephyr-app --build-dir build/nucleo_g474re --pristine
  ```

- Another option is to use the CMake presets directly, if you successfully exported Zephyr to the CMake user package registry. Run `cmake --list-presets -S sample-zephyr-app` to see the four available presets:
  ```bash
  cmake -S sample-zephyr-app --preset nucleo_g474re
  cmake --build build/nucleo_g474re
  ```

- **Flash to ST Nucleo G474RE:**
  ```bash
  west flash --build-dir build/nucleo_g474re --runner openocd
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