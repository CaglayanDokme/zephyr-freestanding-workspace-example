FROM docker.io/zephyrprojectrtos/zephyr-build:v0.29.3

USER root

RUN apt-get update
RUN apt-get install -y --no-install-recommends stow
RUN apt-get install -y --no-install-recommends zsh
RUN apt-get install -y --no-install-recommends curl
RUN rm -rf /var/lib/apt/lists/*

# Set default shell to zsh for user
RUN chsh -s $(which zsh) user

# Mount point for the Claude Code config volume (see devcontainer.json); pre-create it
# so the named volume is initialised with the right owner instead of root.
RUN mkdir -p /home/user/.claude && chown -R user:user /home/user/.claude

# Mount point for the Zephyr source volume (see devcontainer.json); pre-create it so a fresh
# named volume is initialised owned by user instead of root.
RUN mkdir -p /opt/zephyrproject-rtos && chown -R user:user /opt/zephyrproject-rtos

# Some binaries appear in ~/.local/bin, so add that to the PATH
ENV PATH="/home/user/.local/bin:${PATH}"

USER user

RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

