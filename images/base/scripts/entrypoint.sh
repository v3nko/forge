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

# Generate a default user SSH key on first provision. Lives on the persisted home volume, so it is
# created once and reused on subsequent starts.
default_key="${home_dir}/.ssh/id_ed25519"
if [[ ! -f "${default_key}" ]]; then
  ssh-keygen -t ed25519 -N '' -C "${username}@${HOSTNAME:-forge}" -f "${default_key}"
  chmod 600 "${default_key}"
  chmod 644 "${default_key}.pub"
  chown "${username}:${username}" "${default_key}" "${default_key}.pub"
fi

# Persist SSH host keys across image updates and container recreation. Without this,
# openssh-server's build-time host keys change on every image rebuild. Keys are generated once into
# the persisted home volume and restored into /etc/ssh on every start, so the server identity stays
# stable for the lifetime of the home volume.
host_key_store="${home_dir}/.forge/ssh"
mkdir -p "${host_key_store}"

if ls "${host_key_store}"/ssh_host_*_key >/dev/null 2>&1; then
  cp -af "${host_key_store}"/ssh_host_*_key "${host_key_store}"/ssh_host_*_key.pub /etc/ssh/
else
  ssh-keygen -A
  cp -af /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub "${host_key_store}/"
fi

# Reclaim ownership (the recursive chown above runs over the home volume) and enforce the strict
# perms sshd requires for host keys.
chown -R root:root "${home_dir}/.forge"
chmod 700 "${home_dir}/.forge" "${host_key_store}"
chmod 600 "${host_key_store}"/ssh_host_*_key
chmod 644 "${host_key_store}"/ssh_host_*_key.pub
chown root:root /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

exec "$@"
