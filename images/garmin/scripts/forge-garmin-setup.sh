#!/usr/bin/env bash
# forge-garmin-setup — one-time (and re-runnable) Garmin toolchain setup for the forge/garmin image.
#
# Default mode prepares a running container:
#   1. accepts the Connect IQ SDK agreement (no-op once accepted),
#   2. ensures the pinned Connect IQ SDK is downloaded and active,
#   3. downloads the pinned default device set, prompting for a Garmin account login if Garmin 
#      requires one,
#   4. creates the developer-key directory.
#
# --build is used by the image Dockerfile (as user dev): steps 1, 2, 4 plus the 
# /etc/profile.d/forge-garmin.sh PATH shim. Device downloads and Garmin login never happen at image
# build time.
#
# The script is idempotent: re-running it skips work that is already done.
set -euo pipefail

# Pinned default device set.
DEVICES=(
  marqaviator
  epix2pro47mm
  fr255s
  fenix5xplus
  d2air
  legacysagadarthvader
  fenixe
  fr645m
  vivoactive3mlte
  marq2
  fenix5x
  fenix8solar51mm
  instinct3amoled50mm
  fenix6s
  fr255m
  fenix5
  enduro3
  vivoactive4s
)

SDK_VERSION="${CONNECT_IQ_SDK_VERSION:-9.2.0}"
SDK_LINK="/opt/connect-iq-sdk"
MODE="full"

usage() {
  cat <<'EOF'
Usage: forge-garmin-setup [--build]

  (no args)  Prepare the running container: SDK agreement, pinned SDK,
             default device set (may prompt for Garmin login), key directory.
  --build    Image-build mode: agreement, SDK, and the /etc/profile.d PATH
             shim only — no device downloads, no login.
  -h, --help Show this help.
EOF
}

case "${1:-}" in
  "") ;;
  --build) MODE="build" ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Accept the current CONNECT IQ SDK agreement. `agreement view` records the agreement (and prints 
# its acceptance hash); plain `accept` accepts the latest agreement, and the hash-based form is the 
# documented CI-friendly fallback.
ensure_agreement() {
  echo "Checking the Connect IQ SDK agreement..."
  local view_tmp hash
  view_tmp="$(mktemp)"
  connect-iq-sdk-manager agreement view >"${view_tmp}" 2>&1 || true

  if (set +o pipefail; yes | connect-iq-sdk-manager agreement accept); then
    rm -f "${view_tmp}"
    return 0
  fi

  hash="$(grep -Eo '[0-9a-f]{32,64}' "${view_tmp}" | tail -n 1 || true)"
  rm -f "${view_tmp}"
  if [ -n "${hash}" ]; then
    echo "Retrying with acceptance hash..."
    connect-iq-sdk-manager agreement accept --acceptance-hash="${hash}"
  else
    echo "error: could not accept the Connect IQ SDK agreement" >&2
    exit 1
  fi
}

# Make sure the pinned SDK is downloaded and active, and that the stable /opt/connect-iq-sdk shim
# points at the SDK *root* — both PATH entries (Docker ENV and profile.d) use
# ${GARMIN_CONNECT_IQ_SDK}/bin, so the shim must resolve to the directory that contains bin/monkeyc.
ensure_sdk() {
  local bin root
  bin="$(connect-iq-sdk-manager sdk current-path --bin 2>/dev/null || true)"
  if [ -z "${bin}" ] || [ ! -e "${bin}/monkeyc" ]; then
    echo "Downloading Connect IQ SDK ${SDK_VERSION} (first run only)..."
    connect-iq-sdk-manager sdk set "${SDK_VERSION}"
    bin="$(connect-iq-sdk-manager sdk current-path --bin 2>/dev/null || true)"
  fi
  if [ -z "${bin}" ] || [ ! -e "${bin}/monkeyc" ]; then
    echo "error: Connect IQ SDK ${SDK_VERSION} is not available; monkeyc not found" >&2
    exit 1
  fi
  root="$(dirname "${bin}")"
  echo "Connect IQ SDK active at ${bin}"

  if [ "$(readlink -f "${SDK_LINK}" 2>/dev/null || true)" != "$(readlink -f "${root}" 2>/dev/null || true)" ]; then
    as_root ln -sfn "${root}" "${SDK_LINK}"
  fi
  if [ ! -e "${SDK_LINK}/bin/monkeyc" ]; then
    echo "error: ${SDK_LINK}/bin/monkeyc does not resolve; the SDK PATH shim is broken" >&2
    exit 1
  fi

  mkdir -p "${HOME}/.Garmin/keys"
}

# SSH login shells do not inherit Docker ENV, so export the toolchain from profile.d as well (same 
# pattern as forge-android.sh and forge-ansible.sh).
ensure_profile() {
  local content current
  content="export CONNECT_IQ_SDK_VERSION=${SDK_VERSION}
export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
export GARMIN_CONNECT_IQ_SDK=${SDK_LINK}
export PATH=\"\$GARMIN_CONNECT_IQ_SDK/bin:\$JAVA_HOME/bin:\$PATH\""
  current="$(cat /etc/profile.d/forge-garmin.sh 2>/dev/null || true)"
  if [ "${current}" != "${content}" ]; then
    as_root tee /etc/profile.d/forge-garmin.sh >/dev/null <<<"${content}"
    as_root chmod 0644 /etc/profile.d/forge-garmin.sh
  fi
}

device_present() {
  [ -n "$(find "${HOME}/.Garmin" "${HOME}/.connect-iq-sdk-manager" \
    -type d -name "$1" -print -quit 2>/dev/null)" ]
}

# Download any device from the pinned set that is not present yet. Garmin requires a logged-in 
# developer account for device binaries; if the download is rejected, run the interactive login once 
# and resume.
ensure_devices() {
  local id joined
  local missing=()
  for id in "${DEVICES[@]}"; do
    if ! device_present "${id}"; then
      missing+=("${id}")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    echo "All ${#DEVICES[@]} default devices are already present."
    return 0
  fi
  joined="$(IFS=,; echo "${missing[*]}")"
  echo "Downloading ${#missing[@]} device(s): ${joined}"
  if connect-iq-sdk-manager device download -d "${joined}"; then
    return 0
  fi
  echo "Device download was rejected — logging in to a Garmin account is required."
  echo "Complete the Garmin login prompt; the download resumes afterwards."
  connect-iq-sdk-manager login
  connect-iq-sdk-manager device download -d "${joined}"
}

ensure_agreement
ensure_sdk

if [ "${MODE}" = "build" ]; then
  ensure_profile
else
  ensure_devices
fi
