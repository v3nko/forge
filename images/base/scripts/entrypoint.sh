#!/usr/bin/env bash
set -euo pipefail

username="${FORGE_USER:-dev}"
home_dir="/home/${username}"

if [[ ! -d "${home_dir}" ]]; then
  mkdir -p "${home_dir}"
fi

if [[ -d /home-template ]]; then
  shopt -s dotglob nullglob
  for item in /home-template/*; do
    target="${home_dir}/$(basename "${item}")"
    if [[ ! -e "${target}" ]]; then
      cp -a "${item}" "${target}"
    fi
  done
fi

mkdir -p "${home_dir}/.ssh" "${home_dir}/.local/bin" "${home_dir}/.npm" /workspace
chmod 700 "${home_dir}/.ssh"
chown -R "${username}:${username}" "${home_dir}" /workspace

if [[ -n "${FORGE_AUTHORIZED_KEYS:-}" ]]; then
  printf '%s\n' "${FORGE_AUTHORIZED_KEYS}" > "${home_dir}/.ssh/authorized_keys"
elif [[ -n "${FORGE_AUTHORIZED_KEYS_FILE:-}" && -r "${FORGE_AUTHORIZED_KEYS_FILE}" ]]; then
  cp "${FORGE_AUTHORIZED_KEYS_FILE}" "${home_dir}/.ssh/authorized_keys"
fi

if [[ -f "${home_dir}/.ssh/authorized_keys" ]]; then
  chmod 600 "${home_dir}/.ssh/authorized_keys"
  chown "${username}:${username}" "${home_dir}/.ssh/authorized_keys"
fi

exec "$@"
