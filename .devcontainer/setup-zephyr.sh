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
    container_uid="$(id -u)"
    container_gid="$(id -g)"

    sudo install -d -o "${container_uid}" -g "${container_gid}" "${ZEPHYR_WORKSPACE}"
fi

# Only one container may set up a given version at a time. Two containers created together
# would otherwise race on west init and west update, and the repair below would delete a
# .west that another container is still writing.
exec 9> "${ZEPHYR_WORKSPACE}/.setup.lock"
if ! flock --nonblock 9; then
    echo "Another container is setting up ${ZEPHYR_WORKSPACE}; waiting for it to finish"
    flock 9
fi

# west drops a .west directory before it has finished, and its mere presence makes every later
# "west init" abort with "already initialized". So a failed or interrupted first init leaves a
# workspace that can never repair itself. Clean up after ourselves rather than leaving that
# behind, and key the "already set up" test on .west/config, which west writes only on success.
init_failed() {
    rm -rf "${ZEPHYR_WORKSPACE}/.west"
    echo "west init failed; removed the partial ${ZEPHYR_WORKSPACE}/.west so the next container creation starts clean" >&2
    exit 1
}

if [[ -f "${ZEPHYR_WORKSPACE}/.west/config" ]]; then
    echo "Reusing Zephyr ${ZEPHYR_VERSION} west workspace in ${ZEPHYR_WORKSPACE}"
elif [[ -e "${ZEPHYR_WORKSPACE}/.west" ]]; then
    # An earlier attempt died between creating .west and writing its config.
    echo "Found an incomplete west workspace in ${ZEPHYR_WORKSPACE} (no .west/config); repairing"
    rm -rf "${ZEPHYR_WORKSPACE}/.west"

    if [[ -d "${ZEPHYR_WORKSPACE}/zephyr/.git" ]]; then
        # The Zephyr clone itself survived, so rebuild only the missing configuration. This
        # costs nothing and keeps a 2.7 GB download that is very probably fine. If the clone
        # turns out to be at the wrong revision, verify-zephyr.sh reports it on every start;
        # deleting shared source that other projects also use is not this script's call.
        echo "Existing Zephyr clone found; recreating the workspace configuration without re-downloading"
        (cd "${ZEPHYR_WORKSPACE}" && west init --local zephyr) || init_failed
    else
        echo "No usable Zephyr clone; initializing Zephyr ${ZEPHYR_VERSION} from scratch"
        west init \
            --manifest-url https://github.com/zephyrproject-rtos/zephyr \
            --manifest-rev "${ZEPHYR_VERSION}" \
            "${ZEPHYR_WORKSPACE}" || init_failed
    fi
else
    echo "Initializing Zephyr ${ZEPHYR_VERSION} west workspace in ${ZEPHYR_WORKSPACE}"
    west init \
        --manifest-url https://github.com/zephyrproject-rtos/zephyr \
        --manifest-rev "${ZEPHYR_VERSION}" \
        "${ZEPHYR_WORKSPACE}" || init_failed
fi

(
    cd "${ZEPHYR_WORKSPACE}"
    west update "${ZEPHYR_APP_DEPS[@]}"
    west zephyr-export
)
