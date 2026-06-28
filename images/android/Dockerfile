ARG BASE_IMAGE=forge/base:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/v3nko/forge
ARG IMAGE_VERSION=edge

ARG ANDROID_CMDLINE_TOOLS_VERSION=13114758
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG GLAB_VERSION=1.67.0

LABEL org.opencontainers.image.title="Forge Android development image"
LABEL org.opencontainers.image.description="Android development workstation image derived from the Forge base image"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.authors="venko"
LABEL org.opencontainers.image.url="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.source="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.documentation="${IMAGE_SOURCE}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.revision="${IMAGE_REVISION}"
LABEL org.opencontainers.image.vendor="venko"
LABEL org.opencontainers.image.licenses="MPL-2.0"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    jsonnet \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk

# Install the Android command-line tools into the layout sdkmanager expects
# ($ANDROID_HOME/cmdline-tools/latest), accept all licenses so non-interactive
# Gradle/AGP builds can auto-fetch additional packages, then install a baseline
# SDK. The SDK is owned by the dev user so packages can be added over SSH
# (e.g. `sdkmanager "ndk;..."`) without sudo.
RUN mkdir -p "${ANDROID_HOME}" \
  && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -o /tmp/cmdline-tools.zip \
  && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools" \
  && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
  && rm /tmp/cmdline-tools.zip \
  && ( set +o pipefail; yes | "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null ) \
  && "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
    "platform-tools" \
    "platforms;${ANDROID_PLATFORM}" \
    "build-tools;${ANDROID_BUILD_TOOLS}" \
  && chown -R dev:dev "${ANDROID_HOME}"

# GitLab CLI (matches the reference Android image)
RUN curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz" -o /tmp/glab.tar.gz \
  && tar -xzf /tmp/glab.tar.gz -C /tmp \
  && mv /tmp/bin/glab /usr/local/bin/ \
  && rm -rf /tmp/glab.tar.gz /tmp/bin /tmp/CHANGELOG.md /tmp/LICENSE /tmp/README.md

ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${JAVA_HOME}/bin:${PATH}

# SSH login shells do not inherit Docker ENV, so export the Android toolchain
# via profile.d (same pattern as the base image and forge-ansible.sh).
RUN printf '%s\n' \
    'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' \
    'export ANDROID_HOME=/opt/android-sdk' \
    'export ANDROID_SDK_ROOT=/opt/android-sdk' \
    'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH"' \
    > /etc/profile.d/forge-android.sh \
  && chmod 0644 /etc/profile.d/forge-android.sh

USER dev
RUN mkdir -p "${HOME}/.android" "${HOME}/.gradle" \
  && touch "${HOME}/.android/repositories.cfg"
USER root
