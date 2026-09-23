FROM docker.io/zephyrprojectrtos/zephyr-build:v0.29.3

USER root

# The base image leaves this account on /bin/sh. bash is already present and is a reasonable
# interactive default for anyone who has not injected their own dotfiles. Developers who prefer
# another shell install and select it from their own dotfiles; see VS Code's dotfiles.repository
# setting. Nothing personal belongs in this image.
RUN chsh -s /bin/bash user

# Mount point for the Claude Code config volume (see devcontainer.json); pre-create it
# so the named volume is initialised with the right owner instead of root.
RUN mkdir -p /home/user/.claude && chown -R user:user /home/user/.claude

# Mount point for the Zephyr source volume (see devcontainer.json); pre-create it so a fresh
# named volume is initialised owned by user instead of root.
RUN mkdir -p /opt/zephyrproject-rtos && chown -R user:user /opt/zephyrproject-rtos

# Version- and architecture-neutral names for the SDK, so nothing outside this file has to spell
# out "zephyr-sdk-1.0.1" or "x86_64-pokysdk-linux". West and CMake resolve the SDK for themselves
# through the CMake user package registry, but .vscode/launch.json cannot, and naming the versioned
# paths there means an SDK bump silently breaks debugging while the build keeps working.
# ZSDK_VERSION is an environment variable of the base image, so the version is never repeated here.
#
# These are symlinks only, deliberately not added to PATH: the SDK carries 35 target toolchains and
# putting one of them on PATH would make ARM look like this workspace's default target. Nothing in
# the build needs them there either.
RUN ln -s "/opt/toolchains/zephyr-sdk-${ZSDK_VERSION}" /opt/toolchains/zephyr-sdk
RUN ln -s "/opt/toolchains/zephyr-sdk/hosttools/sysroots/$(uname -m)-pokysdk-linux" /opt/toolchains/hosttools

ENV PATH="${PATH}:/opt/toolchains/hosttools/usr/bin"

USER user

# Claude Code CLI: Anthropic's native installer, stable channel, run as user so the CLI lands under
# ~/.local and can update itself at runtime. The Dev Container Feature used before installed a
# root-owned npm global under /usr/local that user could not update (measured 2026-09-23: the
# container sat at 2.1.266 while the host ran 2.1.280) and made Dev Containers build an image per
# workspace. The script is saved to a file first: piped into bash, a failed download would run an
# empty script and the build would pass without claude; `claude --version` makes any other failure
# loud. ~/.claude (pre-created above) is the mount point of the credentials volume named in
# devcontainer.json and its contents seed every fresh volume, so it is reduced to the one settings
# file that selects the update channel; the build-time ~/.claude.json (a machine id minted at
# build) is removed. BuildKit caches this layer: the baked version is only the floor the CLI
# updates from; a rebuild without cache refreshes it. Needs egress to claude.ai and
# downloads.claude.ai. The same lines, user name aside, are in petalinux-infra/docker/Dockerfile.
ENV PATH="${PATH}:/home/user/.local/bin"
RUN export HOME=/home/user \
 && wget -qO /tmp/claude-install.sh https://claude.ai/install.sh \
 && bash /tmp/claude-install.sh stable \
 && rm -f /tmp/claude-install.sh "$HOME/.claude.json" \
 && rm -rf "$HOME/.claude/backups" "$HOME/.claude/downloads" "$HOME/.claude/sessions" \
 && mkdir -p "$HOME/.claude" \
 && printf '{ "autoUpdatesChannel": "stable" }\n' > "$HOME/.claude/settings.json" \
 && claude --version
