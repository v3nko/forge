# Forge Ansible Image

`forge/ansible` is an Ansible development workstation image layered on top of `forge/base`.

It includes the common SSH workstation baseline plus Ansible-focused tooling: Ansible, ansible-core, ansible-lint, Molecule, Molecule Docker plugins, yamllint, netaddr, passlib, pywinrm, and sshpass.

## Image

```sh
docker pull forge/ansible:latest
```

Workspace machines are expected to run prebuilt images published by CI.

## Run

Create a local workspace directory, provide your public SSH key, and start the container from the repository root:

```sh
mkdir -p workspace
export FORGE_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
docker compose up -d ansible
```

Connect using the shared SSH patterns documented in the [base image README](../base/README.md#ssh-access).

The `forge-ansible-home` volume persists `/home`. You can recreate the container without losing shell configuration, SSH state, package caches, Homebrew packages, or user-installed tools.

## Project Containers

Use a project-specific Compose file for each independent Ansible workstation. Start from [../../examples/project/compose.yaml](../../examples/project/compose.yaml) and change:

- `name`
- `FORGE_IMAGE` if using a different image tag
- host SSH port
- host SSH bind address
- home volume name
- workspace bind mount

Each project should get a distinct `/home` named volume. The image can be shared across all projects using the same stack.
