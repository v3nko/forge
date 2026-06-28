# Configuration

Forge is configured with build arguments, environment variables, and Compose volumes. Project-specific Compose files should override only the project name, image tag, port, workspace mount, and home volume name.

The base image includes baseline AI coding CLIs used across workstations: OpenCode (`opencode`), Crush (`crush`), and RTK (`rtk`). The user-local tool path, `/home/dev/.local/bin`, comes first on `PATH`, and npm global installs default to `/home/dev/.local`, so developers can update or replace these tools in the persisted home volume without rebuilding the image.

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

## Android image build arguments

| Variable | Description |
| --- | --- |
| `BASE_IMAGE` | Base image used to derive the Android development image. Default value: `forge/base:latest`. |
| `ANDROID_CMDLINE_TOOLS_VERSION` | Build number of the Android command-line tools package downloaded from Google. Default value: `13114758`. |
| `ANDROID_PLATFORM` | Android platform (SDK API level) pre-installed in the image. Default value: `android-36`. |
| `ANDROID_BUILD_TOOLS` | Android build-tools version pre-installed in the image. Default value: `36.0.0`. |
| `GLAB_VERSION` | GitLab CLI (`glab`) release installed in the image. Default value: `1.67.0`. |

The Android SDK is installed at `/opt/android-sdk` (`ANDROID_HOME`/`ANDROID_SDK_ROOT`) and owned by the `dev` user with all licenses accepted, so Gradle/AGP can auto-fetch additional platforms or build-tools on first build. The image ships no emulator, NDK, CMake, or system Gradle; add SDK components on demand with `sdkmanager` and build projects through their Gradle wrapper.

## Runtime environment variables

| Variable | Description |
| --- | --- |
| `FORGE_AUTHORIZED_KEYS` | Public SSH keys written to `/home/dev/.ssh/authorized_keys` on container start. Default value: empty. |
| `FORGE_AUTHORIZED_KEYS_FILE` | Path to a readable file inside the container whose contents are copied to `/home/dev/.ssh/authorized_keys` when `FORGE_AUTHORIZED_KEYS` is empty. Default value: empty. |
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
