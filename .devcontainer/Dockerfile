FROM docker.io/zephyrprojectrtos/zephyr-build:v0.29.3

USER root

RUN apt-get update
RUN apt-get install -y --no-install-recommends stow
RUN apt-get install -y --no-install-recommends zsh
RUN apt-get install -y --no-install-recommends curl
RUN rm -rf /var/lib/apt/lists/*

# Set default shell to zsh for user
RUN chsh -s $(which zsh) user

# Add ~/.local/bin to PATH for all users/shells
ENV PATH="/home/user/.local/bin:${PATH}"

USER user

RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# Ensure system-wide availability via /usr/local/bin symlink
USER root
RUN ln -sf /home/user/.local/bin/agy /usr/local/bin/agy
USER user
