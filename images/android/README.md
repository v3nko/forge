# Forge Android Image

`forge/android` is an Android development workstation image layered on top of `forge/base`.

It includes the common SSH workstation baseline plus Android-focused tooling: OpenJDK 17, the Android SDK command-line tools, platform-tools, a baseline platform and build-tools, `jsonnet`, and the GitLab CLI (`glab`).

The SDK lives at `/opt/android-sdk` (`ANDROID_HOME`/`ANDROID_SDK_ROOT`) and is owned by the `dev` user with all licenses accepted, so Gradle/AGP can auto-fetch any additional platform or build-tools a project needs on first build. Add more components over SSH with `sdkmanager`, for example the NDK and CMake:

```sh
sdkmanager "ndk;27.0.12077973" "cmake;3.22.1"
```

The image ships no Android emulator or system images (the SSH host has no KVM acceleration) and no system Gradle — use each project's Gradle wrapper (`./gradlew`). The `~/.gradle` cache persists via the home volume.

## Image

```sh
docker pull forge/android:latest
```

Workspace machines are expected to run prebuilt images published by CI.

## Run

Create a local workspace directory, provide your public SSH key, and start the container from the repository root:

```sh
mkdir -p workspace
export FORGE_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
docker compose up -d android
```

Connect using the shared SSH patterns documented in the [base image README](../base/README.md#ssh-access).

The `forge-android-home` volume persists `/home/dev`. You can recreate the container without losing shell configuration, SSH state, package caches, or user-installed tools. SDK packages added under `/opt/android-sdk` live in the image layer, so re-run `sdkmanager` for them after recreating the container.

## Project Containers

Use a project-specific Compose file for each independent Android workstation. Start from [../../examples/project/compose.yaml](../../examples/project/compose.yaml) and change:

- `name`
- `FORGE_IMAGE` if using a different image tag
- host SSH port
- host SSH bind address
- home volume name
- workspace bind mount

Each project should get a distinct `/home/dev` named volume. The image can be shared across all projects using the same stack.
