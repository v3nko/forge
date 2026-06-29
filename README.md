# Forge

Forge is a reusable collection of Docker-based development workstations. It is designed for remote development over SSH on a self-hosted server: each project runs in its own container, while shared image layers provide stable tooling. It is also built with AI-based development in mind, so terminal coding agents are available immediately after connecting.

Image families:

- [`forge/base`](images/base/README.md): shared Ubuntu-based SSH workstation with a non-root `dev` user, persistent home behavior, stable shell tooling, Git, SSH, sudo, Python, Node.js/npm, Homebrew (`brew`), OpenCode (`opencode`), Crush (`crush`), and RTK (`rtk`).
- [`forge/ansible`](images/ansible/README.md): Ansible development workstation layered on top of `forge/base`.
- [`forge/android`](images/android/README.md): Android development workstation layered on top of `forge/base`, with OpenJDK 17 and the Android SDK (no emulator).

AI CLI tools that define the baseline workstation experience are installed in the image by CI. The user-local tool path, `/home/dev/.local/bin`, comes first on `PATH`, so developers can update or replace these CLIs over SSH in the persistent home volume without rebuilding the image.

Workspace machines are expected to run prebuilt images published by CI. The Dockerfiles stay in this repository as the image source of truth, and GitHub Actions publishes them to GHCR. See the image-specific README for usage details.

## Image Publishing

Forge publishes Docker images to GitHub Container Registry through thin trigger workflows and a reusable publisher workflow:

- [`.github/workflows/_images.yaml`](.github/workflows/_images.yaml): reusable build and deploy workflow.
- [`.github/workflows/edge.yaml`](.github/workflows/edge.yaml): edge trigger that computes impacted images from changed paths.
- [`.github/workflows/stable.yaml`](.github/workflows/stable.yaml): stable release trigger.
- [`images/manifest.json`](images/manifest.json): central image definition list used by the reusable workflow.

Configure these repository settings before enabling the workflow:

- Create a repository variable named `FORGE_IMAGE_NAMESPACE`. Set it to the lowercase GHCR image prefix, for example `ghcr.io/my-org/forge` or `ghcr.io/my-user/forge`.
- Allow GitHub Actions to write packages. The workflow uses `GITHUB_TOKEN` with `packages: write` and `contents: read`.
- Ensure the repository has access to create or update the target GHCR packages under `FORGE_IMAGE_NAMESPACE`.

The reusable workflow has two jobs:

- `plan`: expands the selected image set into ordered build metadata and tags.
- `publish`: builds and pushes the selected images once, in dependency order, on the same runner.

Image selection is change-based:

- Changes under `images/base/` publish `base` and every image that depends on it.
- Changes under `images/{image}/` publish that image and every image that depends on it.
- Changes outside `images/` do not publish edge images.
- Stable tags always rebuild and publish every image in the current image family.

### Defining Images

Define every buildable image in [`images/manifest.json`](images/manifest.json). This is the global list used when a workflow passes `images: all`.

Each image entry has:

- `dockerfile`: path to the image Dockerfile.
- `dependencies`: image names that must exist before this image can build.
- `buildArgs`: optional mapping from Docker build argument names to dependency image names.

Example:

```json
{
  "images": {
    "android": {
      "dockerfile": "images/android/Dockerfile",
      "dependencies": ["base"],
      "buildArgs": {
        "BASE_IMAGE": "base"
      }
    }
  }
}
```

When adding a new image:

- Add the image directory under `images/{image}/`.
- Add the image to `images/manifest.json`.

### Edge Lane

Pushes to the `dev` branch publish the `edge` lane.

You can also run the edge workflow manually from GitHub Actions. Use the `images` input to publish `all` or a comma-separated image list such as `base,ansible` or `ansible`.

Published tags:

- `${FORGE_IMAGE_NAMESPACE}/base:edge`
- `${FORGE_IMAGE_NAMESPACE}/ansible:edge`
- `${FORGE_IMAGE_NAMESPACE}/android:edge`

Use `edge` for automatic, frequent, latest working-ish images.

### Stable Lane

Pushing a release tag matching `v{semver}` publishes the `stable` lane. Use tags like `v1.2.3`.

Published tags (per image, shown for `base`):

- `${FORGE_IMAGE_NAMESPACE}/base:stable`
- `${FORGE_IMAGE_NAMESPACE}/base:latest`
- `${FORGE_IMAGE_NAMESPACE}/base:edge`
- `${FORGE_IMAGE_NAMESPACE}/base:1.2.3`

The same tag set is published for every image in the family (`ansible`, `android`, ...).

`latest` is an alias of `stable`: it always points to the newest deliberate release, which is the conventional default pulled when no tag is given. Use `stable`/`latest` for safe-default deployments and `edge` for the newest dev build.

The stable lane also updates the `edge` tag. This keeps `edge` aligned with the newest deliberate safe default after a stable promotion.

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
  android/
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
- User state belongs in a named `/home` volume (covers the `dev` home and Homebrew at `/home/linuxbrew`).
- Project source belongs in `/workspace`.
- SSH bind addresses are configurable, so deployments can choose direct published ports or loopback-only access through the host SSH daemon with `ProxyJump`.
- New stack images should derive from `forge/base` or another stack-specific layer rather than duplicate base setup.

## License

[Mozilla Public License Version 2.0](/LICENSE)
