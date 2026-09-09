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
