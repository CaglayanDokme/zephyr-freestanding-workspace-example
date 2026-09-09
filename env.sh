#!/usr/bin/env bash

# Environment configuration for Zephyr RTOS freestanding workspace
# Default values can be overridden by setting environment variables prior to sourcing this script.

# Specific Zephyr version affects the location of the Zephyr base directory and modules.
export ZEPHYR_VERSION="${ZEPHYR_VERSION:-v4.4.2}"

# West workspace containing Zephyr and its modules for the selected version.
# /opt/zephyrproject-rtos is the Docker named volume "zephyrproject-rtos", declared in
# .devcontainer/devcontainer.json. The dev container is the only supported environment for
# this workspace, so this path is expected to resolve inside it.
export ZEPHYR_WORKSPACE="${ZEPHYR_WORKSPACE:-/opt/zephyrproject-rtos/${ZEPHYR_VERSION}}"

# Zephyr repository within the west workspace.
export ZEPHYR_BASE="${ZEPHYR_BASE:-${ZEPHYR_WORKSPACE}/zephyr}"

# Module dependencies for the application. Adjust as necessary for your specific application requirements.
# Normally, dependencies are in a west.yml file.
# As we don't keep the Zephyr source tree in this workspace, we cannot use west to manage dependencies with a local west.yml
export ZEPHYR_APP_DEPS=(
    cmsis_6
    hal_stm32
)
