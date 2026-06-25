# Configuration

Forge is configured with build arguments, environment variables, and Compose volumes. Project-specific Compose files should override only the project name, image tag, port, workspace mount, and home volume name.

The base image includes baseline AI coding CLIs used across workstations: Antigravity CLI (`agy`), OpenCode (`opencode`), and Crush (`crush`). The user-local tool path, `/home/dev/.local/bin`, comes first on `PATH`, and npm global installs default to `/home/dev/.local`, so developers can update or replace these tools in the persisted home volume without rebuilding the image.

## Base image build arguments

| Variable | Description |
| --- | --- |
| `UBUNTU_VERSION` | Ubuntu release used by the common base image. Default value: `24.04`. |
| `USERNAME` | Linux user created for interactive development. Default value: `dev`. |
| `USER_UID` | UID assigned to the development user. Default value: `1000`. |
| `USER_GID` | GID assigned to the development user. Default value: same as `USER_UID`. |

## Ansible image build arguments

| Variable | Description |
| --- | --- |
| `BASE_IMAGE` | Base image used to derive the Ansible toolchain image. Default value: `forge/base:latest`. |

## Runtime environment variables

| Variable | Description |
| --- | --- |
| `FORGE_AUTHORIZED_KEYS` | Public SSH keys written to `/home/dev/.ssh/authorized_keys` on container start. Default value: empty. |
| `FORGE_SSH_BIND` | Host address used for SSH port binding. Set to `127.0.0.1` for loopback-only access through the host SSH daemon. Default value: empty. |
| `FORGE_SSH_PORT` | Host SSH port exposed by Compose files. Default value: `2222`. |
| `FORGE_IMAGE` | Image used by the generic project example. Default value: `forge/ansible:latest`. |

## SSH access

Compose files publish container SSH using Docker's default bind behavior unless a bind address is set.

Connect directly:

```sh
ssh dev@server-host -p 2222
```

For loopback-only container SSH, set the bind address and connect remotely through the host SSH daemon:

```sh
export FORGE_SSH_BIND=127.0.0.1
docker compose up -d dev
ssh -J user@server-host -p 2222 dev@127.0.0.1
```

## Volumes

Persist `/home/dev` with a named volume per project. This keeps SSH configuration, package manager caches, AI CLI tools, shell customization, and other user-installed state across container recreation.

Bind mount project source into `/workspace`. Keep the workspace separate from the persisted home directory so projects can be recreated or moved without mixing source and user state.
