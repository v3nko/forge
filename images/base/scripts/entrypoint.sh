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

# Ensure OpenSSH permits user environment variables for the configured user and root
if ! grep -q "^Match User ${username},root" /etc/ssh/sshd_config 2>/dev/null; then
  sed -i '/^Match User .*$/,/^[[:space:]]*PermitUserEnvironment/d' /etc/ssh/sshd_config 2>/dev/null || true
  printf '\nMatch User %s,root\n    PermitUserEnvironment yes\n' "${username}" >> /etc/ssh/sshd_config
fi

# Generate environment files for SSH sessions preserving exact values
write_user_environment() {
  local target_dir="$1"
  local target_file="${target_dir}/environment"
  local owner="$2"

  mkdir -p "${target_dir}"
  chmod 700 "${target_dir}"
  chown "${owner}" "${target_dir}"

  local tmp_file
  tmp_file="$(mktemp "${target_dir}/environment.tmp.XXXXXX")"
  chmod 600 "${tmp_file}"
  chown "${owner}" "${tmp_file}"

  while IFS= read -r var_name; do
    case "${var_name}" in
      HOME|USER|LOGNAME|SHELL|PWD|OLDPWD|SHLVL|_|HOSTNAME|TERM|DEBIAN_FRONTEND|FORGE_AUTHORIZED_KEYS|FORGE_AUTHORIZED_KEYS_FILE)
        continue
        ;;
      *)
        if [[ "${!var_name}" != *$'\n'* ]]; then
          printf '%s=%s\n' "${var_name}" "${!var_name}" >> "${tmp_file}"
        fi
        ;;
    esac
  done < <(compgen -e | sort -u)

  mv -f "${tmp_file}" "${target_file}"
  chmod 600 "${target_file}"
  chown "${owner}" "${target_file}"
}

write_user_environment "${home_dir}/.ssh" "${username}:${username}"
write_user_environment "/root/.ssh" "root:root"

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

if [[ -f "${host_key_store}/ssh_host_ed25519_key" ]]; then
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
