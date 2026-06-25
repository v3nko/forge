ARG BASE_IMAGE=forge/base:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="Forge Ansible development image"
LABEL org.opencontainers.image.description="Ansible development workstation image derived from the Forge base image"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    libssl-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
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

USER dev
RUN mkdir -p "${HOME}/.ansible" "${HOME}/.cache" "${HOME}/.local/bin"
USER root
