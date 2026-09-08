#!/usr/bin/env bash

# Runs on every container start (see "postStartCommand" in devcontainer.json).
#
# The west workspace under /opt/zephyrproject-rtos lives in a Docker volume that is mounted
# read-write and shared by every dev container on this host. Nothing stops another project,
# or an earlier session of this one, from checking out a different ref, editing Zephyr in
# place, or leaving a module off its manifest revision. Any of that silently changes what
# this project builds.
#
# This script does not repair anything. It answers one question on every start: is the tree
# still exactly what ${ZEPHYR_VERSION}'s manifest says it should be? A non-zero exit surfaces
# an error notification in VS Code; the container stays usable so the problem can be fixed.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

# Sourced in this process on purpose: ZEPHYR_APP_DEPS is a bash array, and arrays are not
# inherited by child processes even when exported. Reading it from an environment that some
# parent shell sourced would silently yield an empty list and skip check 5 entirely.
source "${repo_root}/env.sh"

fail() {
    printf '\nFAIL: %s\n' "$1" >&2
    printf '\nThe shared Zephyr tree at %s is not in the state this project expects.\n' "${ZEPHYR_WORKSPACE}" >&2
    printf 'It is shared with every other dev container on this host, so check with your team before changing it.\n' >&2
    exit 1
}

# 1. The workspace exists and west finished initialising it. Guarding on .west/config rather
#    than the .west directory is what catches an interrupted first "west init", which would
#    otherwise look like a valid workspace to setup-zephyr.sh forever.
[[ -f "${ZEPHYR_WORKSPACE}/.west/config" ]] \
    || fail "no initialised west workspace at ${ZEPHYR_WORKSPACE}; remove ${ZEPHYR_WORKSPACE}/.west and rebuild the container"

# 2. Zephyr is at the tag we asked for, not merely at some Zephyr.
actual_tag="$(git -C "${ZEPHYR_BASE}" describe --tags --exact-match 2>/dev/null || true)"
[[ "${actual_tag}" == "${ZEPHYR_VERSION}" ]] \
    || fail "Zephyr is at '${actual_tag:-no tag}', expected ${ZEPHYR_VERSION}"

# 3. HEAD is detached, as west leaves it. A branch means somebody checked one out, and a
#    branch can move under every other project sharing this tree.
branch="$(git -C "${ZEPHYR_BASE}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
[[ "${branch}" == "HEAD" ]] \
    || fail "Zephyr is on branch '${branch}', expected a detached HEAD at ${ZEPHYR_VERSION}"

# 4. Nobody edited Zephyr in place.
if [[ -n "$(git -C "${ZEPHYR_BASE}" status --porcelain --untracked-files=no)" ]]; then
    fail "Zephyr has local modifications:
$(git -C "${ZEPHYR_BASE}" status --short --untracked-files=no | head -10)"
fi

# 5. Every module this application declares is actually cloned. Modules another project needs
#    but this one does not are ignored, so projects may declare different sets. Without this
#    check a missing module surfaces much later as an unmet Kconfig dependency naming no module.
for dep in "${ZEPHYR_APP_DEPS[@]}"; do
    dep_path="$(west -z "${ZEPHYR_BASE}" list -f '{path}' "${dep}" 2>/dev/null || true)"
    [[ -n "${dep_path}" && -d "${ZEPHYR_WORKSPACE}/${dep_path}/.git" ]] \
        || fail "module '${dep}' is not cloned; run: (cd ${ZEPHYR_WORKSPACE} && west update ${dep})"
done

# 6. Every cloned project sits at the revision the manifest pins, and none is dirty. west
#    compare covers revision drift and local changes across all projects at once and prints
#    nothing when the workspace matches. It honours .gitignore, so ordinary build droppings
#    such as __pycache__ do not trip it.
drift="$(cd "${ZEPHYR_WORKSPACE}" && west compare 2>&1)"
[[ -z "${drift}" ]] \
    || fail "workspace does not match the ${ZEPHYR_VERSION} manifest:
$(printf '%s' "${drift}" | head -24)"

printf 'Zephyr %s verified: %s clean, at the manifest revision, with %s present.\n' \
    "${ZEPHYR_VERSION}" "${ZEPHYR_BASE}" "${ZEPHYR_APP_DEPS[*]}"
