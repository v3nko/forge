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

# Generate a default user SSH key on first provision. Lives on the persisted
# home volume, so it is created once and reused on subsequent starts.
default_key="${home_dir}/.ssh/id_ed25519"
if [[ ! -f "${default_key}" ]]; then
  ssh-keygen -t ed25519 -N '' -C "${username}@${HOSTNAME:-forge}" -f "${default_key}"
  chmod 600 "${default_key}"
  chmod 644 "${default_key}.pub"
  chown "${username}:${username}" "${default_key}" "${default_key}.pub"
fi

exec "$@"
