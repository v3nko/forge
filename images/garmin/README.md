# Forge Garmin Image

`forge/garmin` is a Garmin Connect IQ app and watchface development workstation image layered on top of `forge/base`.

It includes the common SSH workstation baseline plus Garmin-focused tooling: Eclipse Temurin 21 (runs the Monkey C compiler), the pinned `connect-iq-sdk-manager` CLI, and a Connect IQ SDK (pinned, agreement accepted at image build) with `monkeyc` and friends on `PATH`. The image ships **no simulator and no X** — you compile in the container and run the app or watchface in the simulator on your local machine.

Device binaries are not baked into the image. Download them once at first run into the persistent home volume:

```sh
forge-garmin-setup
```

The script is idempotent and re-runnable. It:

1. accepts the Connect IQ SDK agreement (no-op once accepted),
2. downloads and activates the pinned SDK if it is missing (e.g. on a home volume created before this image existed),
3. downloads the default device set,
4. creates `~/.Garmin/keys`.

Garmin requires a logged-in developer account for device binaries. If the download is rejected, the script runs the interactive `connect-iq-sdk-manager login` for you and resumes. To log in ahead of time (or to log in non-interactively), configure `GARMIN_USERNAME` and `GARMIN_PASSWORD` via Docker Compose. The container automatically populates `~/.ssh/environment` on startup so credentials are ready upon SSH login.

Manual equivalents, if you prefer:

```sh
connect-iq-sdk-manager agreement view
connect-iq-sdk-manager agreement accept
connect-iq-sdk-manager login
connect-iq-sdk-manager device download -d fenix8solar51mm,venu3
connect-iq-sdk-manager device download --manifest=manifest.xml   # devices from a project manifest
```

## Developer key

`monkeyc` signs development builds with a developer key. The image ships none — generate one into the persisted home volume:

```sh
mkdir -p ~/.Garmin/keys
ssh-keygen -t rsa -b 4096 -m PEM -N '' -f ~/.Garmin/keys/developer_key
```

The VS Code Monkey C extension can also generate one (Command Palette → "Monkey C: Generate a Developer Key"). A developer key is for development and sideloading only; store submission uses Garmin's signing flow.

## Building an app or watchface

From the project directory in `/workspace`:

```sh
monkeyc -f monkey.jungle -o bin/myapp.prg \
  -y ~/.Garmin/keys/developer_key \
  -d fenix8solar51mm
```

To target a device that is not in the default set, download it first (`connect-iq-sdk-manager device download -d <device>`), or pull every device from your `manifest.xml`:

```sh
connect-iq-sdk-manager device download --manifest=manifest.xml
```

## Running on your local simulator

The container compiles; your local machine simulates:

1. Edit over VS Code Remote-SSH (or plain SSH) against the container.
2. Build the `.prg` inside the container as shown above.
3. Move the artifact to your local machine — the `./workspace` bind mount already lands it on the Docker host if Docker runs locally; otherwise copy it out:

   ```sh
   scp -P 2222 dev@server-host:/workspace/myapp/bin/myapp.prg .
   ```

4. Load the `.prg` in the Connect IQ simulator on your local machine (VS Code Monkey C extension, local SDK install, or the local simulator CLI).

## Image

```sh
docker pull forge/garmin:latest
```

Workspace machines are expected to run prebuilt images published by CI.

## Run

Create a local workspace directory, provide your public SSH key, and start the container from the repository root:

```sh
mkdir -p workspace
export FORGE_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
docker compose up -d garmin
```

Connect using the shared SSH patterns documented in the [base image README](../base/README.md#ssh-access).

The `forge-garmin-home` volume persists `/home`. You can recreate the container without losing shell configuration, SSH state, package caches, Homebrew packages, SDK state, device binaries, or user-installed tools. The pinned SDK is seeded into fresh home volumes from the image; on home volumes created before this image existed, run `forge-garmin-setup` once.

## Project Containers

Use a project-specific Compose file for each independent Garmin workstation. Start from [../../examples/project/compose.yaml](../../examples/project/compose.yaml) and change:

- `name`
- `FORGE_IMAGE` if using a different image tag
- host SSH port
- host SSH bind address
- home volume name
- workspace bind mount

Each project should get a distinct `/home` named volume. The image can be shared across all projects using the same stack.
