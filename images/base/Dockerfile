ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/v3nko/forge
ARG IMAGE_VERSION=edge

LABEL org.opencontainers.image.title="Forge base development image"
LABEL org.opencontainers.image.description="Reusable SSH-ready base image for persistent Docker development workstations"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.authors="venko"
LABEL org.opencontainers.image.url="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.source="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.documentation="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.revision="${IMAGE_REVISION}"
LABEL org.opencontainers.image.vendor="venko"
LABEL org.opencontainers.image.licenses="MPL-2.0"
LABEL devcontainer.metadata='[{"remoteUser":"dev","containerUser":"dev","init":true}]'

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -o Acquire::Retries=5 \
  && apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
    bash-completion \
    build-essential \
    ca-certificates \
    curl \
    fd-find \
    dumb-init \
    file \
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
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
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
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 \
  && if getent group "${USER_GID}" >/dev/null; then \
    existing_group="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    if [[ "${existing_group}" != "${USERNAME}" ]]; then \
      if getent group "${USERNAME}" >/dev/null; then groupdel "${USERNAME}"; fi; \
      groupmod --new-name "${USERNAME}" "${existing_group}"; \
    fi; \
  else \
    groupadd --gid "${USER_GID}" "${USERNAME}"; \
  fi \
  && if id -u "${USERNAME}" >/dev/null 2>&1; then \
    usermod --uid "${USER_UID}" --gid "${USER_GID}" --home "/home/${USERNAME}" --shell /bin/bash "${USERNAME}"; \
  elif getent passwd "${USER_UID}" >/dev/null; then \
    existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
    usermod --login "${USERNAME}" --gid "${USER_GID}" --home "/home/${USERNAME}" --move-home --shell /bin/bash "${existing_user}"; \
  else \
    useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}"; \
  fi \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
  && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
  && mkdir -p "/home/${USERNAME}/.local/bin" "/home/${USERNAME}/.npm" /var/run/sshd /workspace /home-template \
  && chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}" \
  && cp -a "/home/${USERNAME}/." /home-template/ \
  && printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' > /etc/profile.d/forge-path.sh \
  && chmod 0644 /etc/profile.d/forge-path.sh \
  && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
  && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
  && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

RUN npm install -g \
    opencode-ai \
    @charmland/crush \
  && curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | RTK_INSTALL_DIR=/usr/local/bin sh \
  && npm cache clean --force

USER dev
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
USER root
RUN printf '%s\n' 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' 'export PATH="$HOME/.local/bin:$PATH"' > /etc/profile.d/homebrew.sh \
  && chmod 0644 /etc/profile.d/homebrew.sh \
  && cp -a "/home/dev/." /home-template/

COPY images/base/scripts/entrypoint.sh /usr/local/bin/forge-entrypoint
RUN chmod +x /usr/local/bin/forge-entrypoint

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
ENV FORGE_USER=${USERNAME}
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.local
ENV PATH=/home/${USERNAME}/.local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}

WORKDIR /workspace

EXPOSE 22

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/forge-entrypoint"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
