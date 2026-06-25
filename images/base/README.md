# Forge Base Image

`forge/base` is the common SSH workstation image used by stack-specific Forge images.

It provides a non-root `dev` user, SSH server, sudo, common shell utilities, Git, Node.js/npm, and baseline AI coding CLIs: Antigravity CLI (`agy`), OpenCode (`opencode`), and Crush (`crush`).

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

## Persistent State

Persist `/home/dev` with a named volume per project. This keeps SSH configuration, package manager caches, AI CLI tools, shell customization, and other user-installed state across container recreation.

Bind mount project source into `/workspace`. Keep the workspace separate from the persisted home directory so projects can be recreated or moved without mixing source and user state.
