ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

LABEL org.opencontainers.image.title="Forge base development image"
LABEL org.opencontainers.image.description="Reusable SSH-ready base image for persistent Docker development workstations"
LABEL devcontainer.metadata='[{"remoteUser":"dev","containerUser":"dev","init":true}]'

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    fd-find \
    dumb-init \
    git \
    gnupg \
    iproute2 \
    jq \
    less \
    locales \
    lsb-release \
    man-db \
    nano \
    nodejs \
    npm \
    openssh-server \
    openssh-client \
    procps \
    rsync \
    sudo \
    tar \
    tmux \
    tree \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
    zsh \
  && locale-gen en_US.UTF-8 \
  && groupadd --gid "${USER_GID}" "${USERNAME}" \
  && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}" \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
  && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
  && mkdir -p "/home/${USERNAME}/.local/bin" "/home/${USERNAME}/.npm" /var/run/sshd /workspace /home-template \
  && chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}" \
  && cp -a "/home/${USERNAME}/." /home-template/ \
  && printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' > /etc/profile.d/forge-path.sh \
  && chmod 0644 /etc/profile.d/forge-path.sh \
  && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
  && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
  && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    opencode-ai \
    @charmland/crush \
  && curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir /usr/local/bin \
  && npm cache clean --force

COPY images/base/scripts/entrypoint.sh /usr/local/bin/forge-entrypoint
RUN chmod +x /usr/local/bin/forge-entrypoint

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
ENV FORGE_USER=${USERNAME}
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.local
ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

WORKDIR /workspace

EXPOSE 22

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/forge-entrypoint"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
