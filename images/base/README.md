# Forge Base Image

`forge/base` is the common SSH workstation image used by stack-specific Forge images.

It provides a non-root `dev` user, SSH server, sudo, common shell utilities, Git, Python, Node.js/npm, Homebrew (`brew`), and baseline AI coding CLIs: OpenCode (`opencode`), Crush (`crush`), and RTK (`rtk`).

The user-local tool path, `/home/dev/.local/bin`, comes first on `PATH`, so developers can update or replace user-facing CLIs in the persisted home volume without rebuilding the image.

## SSH Access

Forge containers expose SSH on container port `22`. Project Compose files publish that port to a host port, usually `2222`.

Connect directly when the host port is reachable:

```sh
ssh dev@server-host -p 2222
```

For a safer remote setup, bind the container SSH port to host loopback and jump through the host SSH service:

```sh
export FORGE_SSH_BIND=127.0.0.1
docker compose up -d dev
ssh -J user@server-host -p 2222 dev@127.0.0.1
```

Stack-specific Compose files should expose `FORGE_SSH_BIND` and `FORGE_SSH_PORT` for this pattern.

## Authorized Keys

Forge containers accept SSH authorized keys in two ways:

- `FORGE_AUTHORIZED_KEYS`: inline public keys.
- `FORGE_AUTHORIZED_KEYS_FILE`: path to a readable file inside the container.

When both are set, `FORGE_AUTHORIZED_KEYS` takes precedence. Use `FORGE_AUTHORIZED_KEYS_FILE` when provisioning containers with a read-only host mount.

## Persistent State

Persist `/home` with a named volume per project. This covers the `dev` home directory and Homebrew (`/home/linuxbrew`), so SSH configuration, package manager caches, AI CLI tools, Homebrew packages, shell customization, and other user-installed state survive container recreation.

Bind mount project source into `/workspace`. Keep the workspace separate from the persisted home directory so projects can be recreated or moved without mixing source and user state.
