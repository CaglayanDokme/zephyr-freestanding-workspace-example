#!/usr/bin/env bash

# Runs once per container creation (see "postCreateCommand" in devcontainer.json).
#
# Ensures the west workspace for ${ZEPHYR_VERSION} exists inside the shared Docker volume mounted at
# /opt/zephyrproject-rtos, fetches the application's module dependencies, and registers Zephyr in this
# container's CMake user package registry. The volume persists across rebuilds, so an existing checkout
# is reused; the CMake registry lives in the container home and is recreated here every time.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

source "${repo_root}/env.sh"

# The Dockerfile pre-creates the mount point owned by the container user, so a fresh volume is writable.
# A volume created before that fix (or populated as root) needs a one-off ownership fix.
if ! mkdir -p "${ZEPHYR_WORKSPACE}" 2>/dev/null || [[ ! -w "${ZEPHYR_WORKSPACE}" ]]; then
    sudo install -d -o "$(id -u)" -g "$(id -g)" "${ZEPHYR_WORKSPACE}"
fi

if [[ ! -d "${ZEPHYR_WORKSPACE}/.west" ]]; then
    echo "Initializing Zephyr ${ZEPHYR_VERSION} west workspace in ${ZEPHYR_WORKSPACE}"
    west init \
        --manifest-url https://github.com/zephyrproject-rtos/zephyr \
        --manifest-rev "${ZEPHYR_VERSION}" \
        "${ZEPHYR_WORKSPACE}"
else
    echo "Reusing Zephyr ${ZEPHYR_VERSION} west workspace in ${ZEPHYR_WORKSPACE}"
fi

(
    cd "${ZEPHYR_WORKSPACE}"
    west update "${ZEPHYR_APP_DEPS[@]}"
    west zephyr-export
)
