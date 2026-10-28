ARG BASE_IMAGE=forge/base:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/v3nko/forge
ARG IMAGE_VERSION=edge

ARG CONNECT_IQ_SDK_VERSION=9.2.0
ARG CONNECT_IQ_SDK_MANAGER_VERSION=0.8.4

LABEL org.opencontainers.image.title="Forge Garmin development image"
LABEL org.opencontainers.image.description="Garmin Connect IQ app and watchface development image derived from the Forge base image"
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

# Eclipse Temurin 21 (Adoptium apt repository) runs monkeyc and the rest of the Connect IQ SDK's JVM
# tooling.
RUN install -d -m 0755 /etc/apt/keyrings \
  && curl -fsSL --retry 3 https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo "${VERSION_CODENAME}") main" > /etc/apt/sources.list.d/adoptium.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends temurin-21-jdk \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Pinned connect-iq-sdk-manager release, checksum-verified against the
# release's checksums.txt (amd64 only, like the sibling images).
RUN tmp="$(mktemp -d)" \
  && base_url="https://github.com/lindell/connect-iq-sdk-manager-cli/releases/download/v${CONNECT_IQ_SDK_MANAGER_VERSION}" \
  && tarball="connect-iq-sdk-manager-cli_${CONNECT_IQ_SDK_MANAGER_VERSION}_Linux_x86_64.tar.gz" \
  && curl -fsSL --retry 3 "${base_url}/${tarball}" -o "${tmp}/${tarball}" \
  && curl -fsSL --retry 3 "${base_url}/checksums.txt" -o "${tmp}/checksums.txt" \
  && expected="$(grep -F "${tarball}" "${tmp}/checksums.txt" | tr '\t' ' ' | cut -d ' ' -f 1)" \
  && echo "${expected}  ${tmp}/${tarball}" | sha256sum -c - > /dev/null \
  && tar -xzf "${tmp}/${tarball}" -C "${tmp}" \
  && install -m 0755 "${tmp}/connect-iq-sdk-manager" /usr/local/bin/connect-iq-sdk-manager \
  && rm -rf "${tmp}" \
  && connect-iq-sdk-manager --help > /dev/null

ENV CONNECT_IQ_SDK_VERSION=${CONNECT_IQ_SDK_VERSION}
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
ENV GARMIN_CONNECT_IQ_SDK=/opt/connect-iq-sdk
ENV PATH=${GARMIN_CONNECT_IQ_SDK}/bin:${JAVA_HOME}/bin:${PATH}

COPY images/garmin/scripts/forge-garmin-setup.sh /usr/local/bin/forge-garmin-setup
RUN chmod 0755 /usr/local/bin/forge-garmin-setup

# Bake the SDK as user dev: accept the Garmin SDK agreement, download and activate the pinned SDK, 
# write the profile.d PATH shim, create ~/.Garmin/keys, and keep the /opt/connect-iq-sdk symlink 
# pointed at the active SDK. Device binaries and Garmin login are runtime steps 
# (forge-garmin-setup), not build steps, so the image build needs no Garmin credentials.
USER dev
RUN forge-garmin-setup --build

# The named /home volume masks /home/dev on first container start, so mirror everything the build 
# added to the dev home into /home-template (the base entrypoint copies template entries that are 
# missing into a fresh volume).
USER root
RUN for dir in .Garmin .connect-iq-sdk-manager .cache; do \
      if [ -e "/home/dev/${dir}" ]; then cp -a "/home/dev/${dir}" /home-template/; fi; \
    done
