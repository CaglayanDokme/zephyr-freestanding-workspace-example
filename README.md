# Zephyr Freestanding Application Workspace Example

A basic Zephyr RTOS "Hello World" application configured for STM32 Nucleo-G474RE showcasing a freestanding application structure.

## Overview

This project demonstrates:
- Freestanding application structure pointing to a shared Zephyr source tree via the `ZEPHYR_BASE` environment variable.
- A single place, [env.sh](env.sh), where the Zephyr version and the application's module dependencies are declared.
- Docker Dev Container configuration for development and debugging.

> **The dev container needs a Linux host.** Docker Desktop on Windows or macOS runs containers in a virtual machine with neither USB passthrough nor host networking, so a container there can reach no board. The board itself may be plugged into any machine, a Windows laptop included, as long as the container runs on Linux; see [Probe Access](#probe-access).
>
> Everything the build needs, west, CMake, Ninja, Python packages and the Zephyr SDK, comes from the container image rather than from this repository, so the commands below will not work on a bare host either. If you want a host installation anyway, follow Zephyr's own [Getting Started Guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html); this repository does not document or test that path.

## Prerequisites

For the dev container path you need:

- **Docker Engine 18.06 or newer**, installed from Docker's own repositories. On Ubuntu the `docker` snap package is **not** supported by the Dev Containers extension, and Docker Desktop cannot reach the debug probe.
- **Your user in the `docker` group**: `sudo usermod -aG docker $USER`, then log out and back in.
- **VS Code** with the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).
- **Disk space.** This is a large image. The figures below are measured, not estimated, for Zephyr v4.4.2 on a linux/amd64 host (image sizes re-measured 2026-09-23 after Claude Code moved from the Dev Container Feature into the Dockerfile: the feature layer went, the CLI came in).

| What | Size |
| --- | --- |
| Base image download | 7.7 GB compressed (amd64) |
| Base image unpacked | 31.8 GB |
| Image after this repo's Dockerfile (Claude Code CLI included) | 32.2 GB |
| Dev Containers uid-remap layer per host user (copies the account's home, 217 MB of it the CLI) | measured 217 MB on the PetaLinux image, same mechanism |
| Shared Zephyr volume, per version | ~2.7 GB |

Budget roughly **40 GB free** for the image plus one Zephyr version, and another ~2.7 GB for each additional version you keep in the volume.

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

Run these in a container terminal, from the repository root; `west` commands need `source env.sh` first (see [Environment variables](#environment-variables)). [sample-zephyr-app/CMakePresets.json](sample-zephyr-app/CMakePresets.json) is the one place a build is described: the board, and for the Debug presets the Kconfig fragment [sample-zephyr-app/debug.conf](sample-zephyr-app/debug.conf), which selects `-Og` and thread awareness. The Release presets build Zephyr's defaults, `-Os`. `CMAKE_BUILD_TYPE` is deliberately not set: Zephyr takes the optimization level from Kconfig, and CMake's own `Release` flags would smuggle `-DNDEBUG` into the build. Every preset writes to `build/<preset>`, so one board never overwrites another's tree, and the debug configurations find the ELF there.

- **Configure and build:** `cmake --list-presets -S sample-zephyr-app` shows the four presets. CMake Tools in VS Code drives the same presets.
  ```bash
  cmake -S sample-zephyr-app --preset nucleo_g474re
  cmake --build build/nucleo_g474re
  ```

- **`west build`** works on a tree a preset configured, and is what `west flash` runs before flashing. Do not configure with `west build --board ... --pristine` into `build/<preset>`: west then configures with Zephyr's defaults, not the preset's, and the tree quietly loses `-Og` and the flash runner. A west-only tree belongs in another directory, such as `build/west`.
  ```bash
  west build --build-dir build/nucleo_g474re
  ```

- **Flash, probe on the container host:** needs the udev rules from [Probe Access](#probe-access). The nucleo presets set `BOARD_FLASH_RUNNER=openocd`, because Zephyr's default flasher for this board, STM32CubeProgrammer, is not in the image. With the probe on your local machine, flash through GDB instead; see [Debugging](#debugging).
  ```bash
  west flash --build-dir build/nucleo_g474re
  ```

## Probe Access

Where the board is plugged in decides how it is reached. Both routes debug from the same VS Code window; only flashing differs.

**Probe on the container host**, the machine running the dev container. Install OpenOCD's udev rules on the **host**, not in the container: the container is given the host's device nodes, but the host decides who may write to them. Install them once, then unplug and replug the board.

```bash
sudo curl -fsSL -o /etc/udev/rules.d/60-openocd.rules \
    https://raw.githubusercontent.com/openocd-org/openocd/master/contrib/60-openocd.rules
sudo udevadm control --reload
```

`west flash` and the *probe on the container host* launch configuration then work as they are.

**Probe on your local machine**, typically a Windows laptop in front of you while the container runs on a Linux machine you reach over SSH. Nothing is forwarded at USB level: OpenOCD runs next to the board and its GDB port is carried to the container's `localhost:3333` by an SSH reverse forward. Flashing goes through GDB's `load`, because `west flash` starts its own OpenOCD and expects the probe in the container. Setup in [docs/remote-debugging.md](docs/remote-debugging.md).

## Debugging

Both hardware configurations need the host-side probe access described above.

VS Code launch configurations are provided in [.vscode/launch.json](.vscode/launch.json):
- **Debug with OpenOCD (Nucleo G474RE)**: Launches OpenOCD and connects GDB to the board via ST-Link.
- **Attach to OpenOCD Server**: Connects GDB to an OpenOCD instance running inside the container on port 3333.

## AI Tools

### Claude Code in the Dev Container
Claude Code is installed into the image by Anthropic's [native installer](https://code.claude.com/docs/en/setup) at build time (see [.devcontainer/Dockerfile](.devcontainer/Dockerfile)), as `user` under `~/.local` on the `stable` channel, so the CLI can update itself inside the running container. A rebuilt container starts from the version baked into the image and catches up in the background; `claude doctor` shows the version, the channel and the last update attempt, `claude update` forces one. The VS Code extension (`anthropic.claude-code`, listed under `customizations`) brings its own copy of the CLI for the chat panel; the terminal `claude` is the one from the image. Both use the same `~/.claude`.

- On first use, open a terminal in the container, run `claude`, and sign in with your company Claude Team account in the browser. If the browser finishes but the terminal does not notice, paste the code shown in the browser at the `Paste code here if prompted` prompt.
- Authentication, settings and session history live in the Docker named volume `claude-code-config-<your user>` (`${localEnv:USER}` in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)), mounted at `/home/user/.claude` with `CLAUDE_CONFIG_DIR` pointing at it. The volume is shared by every dev container of yours on this host that mounts it, the PetaLinux ones included, so you sign in once per machine and stay signed in across rebuilds. To start over, sign out with `/logout` (this signs out every container sharing the volume) or run `docker volume rm claude-code-config-<your user>`.

> The volume holds your Claude Code credentials. Anything that runs inside the container can read them: `claude --dangerously-skip-permissions`, but also the build itself — west, CMake and the code they fetch. This container also runs `--privileged` with `/dev` and passwordless `sudo`, so `sudo` inside it is root on the host; treat Claude's permission prompts accordingly.