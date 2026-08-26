# Zephyr Freestanding Application Workspace Example

A basic Zephyr RTOS "Hello World" application configured for STM32 Nucleo-G474RE showcasing a freestanding application structure.

## Overview

This project demonstrates:
- Freestanding application structure pointing to a central or local Zephyr source tree via the `ZEPHYR_BASE` environment variable.
- Portable environment setup via [env.sh](env.sh) suitable for local development, containers, and CI/CD pipelines.
- Docker Dev Container configuration for development and debugging.

## Environment Setup

### 1. Configure Environment Variables
Source the [env.sh](env.sh) script to set default environment variables:

```bash
source env.sh
```

This sets the following default variables (which can be overridden prior to sourcing):
- `ZEPHYR_VERSION` (default: `v4.4.2`)
- `ZEPHYR_BASE` (default: `/opt/zephyrproject-rtos/${ZEPHYR_VERSION}/zephyr`)
- `ZEPHYR_APP_DEPS` (default: `"cmsis_6 hal_stm32"`)

To use custom paths on your local machine or in CI/CD, simply override them:
```bash
ZEPHYR_VERSION=v4.3.1; ZEPHYR_BASE=~/zephyrproject/zephyr; source env.sh;
```

### 2. Initialize Zephyr Source Tree (if not already present)
If the Zephyr source tree is not yet initialized at `${ZEPHYR_BASE}`, run:

```bash
west init --manifest-url https://github.com/zephyrproject-rtos/zephyr --manifest-rev ${ZEPHYR_VERSION} ${ZEPHYR_BASE}
```

### 3. Update Application Dependencies
Fetch/update the specific modules required by the application:

```bash
west update "${ZEPHYR_APP_DEPS[@]}"
```

### 4. Register Zephyr with CMake
Register the Zephyr installation to the CMake user package registry:

```bash
west zephyr-export
```

> Without this step, CMake will not be able to locate the Zephyr installation when building the application.

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
