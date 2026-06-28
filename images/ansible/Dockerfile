ARG BASE_IMAGE=forge/base:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/v3nko/forge
ARG IMAGE_VERSION=edge

LABEL org.opencontainers.image.title="Forge Ansible development image"
LABEL org.opencontainers.image.description="Ansible development workstation image derived from the Forge base image"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.authors="venko"
LABEL org.opencontainers.image.url="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.source="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.documentation="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.revision="${IMAGE_REVISION}"
LABEL org.opencontainers.image.vendor="venko"
LABEL org.opencontainers.image.licenses="MPL-2.0"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libffi-dev \
    libssl-dev \
    sshpass \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/ansible-venv \
  && /opt/ansible-venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
  && /opt/ansible-venv/bin/pip install --no-cache-dir \
    ansible \
    ansible-core \
    ansible-lint \
    molecule \
    molecule-plugins[docker] \
    netaddr \
    passlib \
    pywinrm \
    yamllint

ENV PATH=/opt/ansible-venv/bin:${PATH}

RUN printf '%s\n' 'export PATH="/opt/ansible-venv/bin:$PATH"' > /etc/profile.d/forge-ansible.sh \
  && chmod 0644 /etc/profile.d/forge-ansible.sh

USER dev
RUN mkdir -p "${HOME}/.ansible" "${HOME}/.cache" "${HOME}/.local/bin"
USER root
