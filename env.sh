#!/usr/bin/env bash

# Environment configuration for Zephyr RTOS freestanding workspace
# Default values can be overridden by setting environment variables prior to sourcing this script.

# Specific Zephyr version affects the location of the Zephyr base directory and modules.
export ZEPHYR_VERSION="${ZEPHYR_VERSION:-v4.4.2}"

# Common installation path for Zephyr RTOS, fundamental for freestanding application development.
# If using containers, make sure that this path is correctly mounted and accessible.
export ZEPHYR_BASE="${ZEPHYR_BASE:-/opt/zephyrproject-rtos/${ZEPHYR_VERSION}/zephyr}"

# Module dependencies for the application. Adjust as necessary for your specific application requirements.
# Normally, dependencies are in a west.yml file.
# As we don't keep the Zephyr source tree in this workspace, we cannot use west to manage dependencies with a local west.yml
export ZEPHYR_APP_DEPS=(
    cmsis_6
    hal_stm32
)
