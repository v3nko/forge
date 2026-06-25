# Forge

Forge is a reusable collection of Docker-based development workstations. It is designed for remote development over SSH on a self-hosted server: each project runs in its own container, while shared image layers provide stable tooling. It is also built with AI-based development in mind, so terminal coding agents are available immediately after connecting.

Image families:

- [`forge/base`](images/base/README.md): shared Ubuntu-based SSH workstation with a non-root `dev` user, persistent home behavior, stable shell tooling, Git, SSH, sudo, Node.js/npm, Antigravity CLI (`agy`), OpenCode (`opencode`), and Crush (`crush`).
- [`forge/ansible`](images/ansible/README.md): Ansible development workstation layered on top of `forge/base`.

AI CLI tools that define the baseline workstation experience are installed in the image by CI. The user-local tool path, `/home/dev/.local/bin`, comes first on `PATH`, so developers can update or replace these CLIs over SSH in the persistent home volume without rebuilding the image.

Workspace machines are expected to run prebuilt images published by CI. The Dockerfiles stay in this repository as the image source of truth; CI should build them with [compose.build.yaml](compose.build.yaml). See the image-specific README for usage details.

## CI build

Build images in CI, then publish them to the registry used by workspace machines:

```sh
docker compose -f compose.build.yaml build base ansible
docker compose -f compose.build.yaml push base ansible
```

## Image layout

```text
images/
  base/
    Dockerfile
    README.md
    scripts/entrypoint.sh
  ansible/
    Dockerfile
    README.md
examples/
  project/compose.yaml
docs/
  configuration.md
```

## Design notes

- Images contain stable tooling: OS packages, runtimes, SDKs, package managers, SSH server, and common shell utilities.
- Containers behave like persistent workstations, not disposable CI runners.
- User state belongs in a named `/home/dev` volume.
- Project source belongs in `/workspace`.
- SSH bind addresses are configurable, so deployments can choose direct published ports or loopback-only access through the host SSH daemon with `ProxyJump`.
- New stack images should derive from `forge/base` or another stack-specific layer rather than duplicate base setup.
