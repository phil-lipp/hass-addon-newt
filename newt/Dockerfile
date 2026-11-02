ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM $BUILD_FROM

LABEL org.opencontainers.image.source=https://github.com/phil-lipp/hass-addon-newt

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
ARG NEWT_VERSION="1.19.0"
# SHA256 checksums for NEWT_VERSION above. Must be updated together with NEWT_VERSION.
# Fetch them with:
#   for a in amd64 arm64; do printf '%s ' "$a"; \
#     curl -sL "https://github.com/fosrl/newt/releases/download/${NEWT_VERSION}/newt_linux_$a" \
#     | sha256sum | cut -d' ' -f1; done
ARG NEWT_SHA256_AMD64="6d40e223fa49d8bcfa9b7094208c58ff616997979bff7c884d0af61fcc1c5376"
ARG NEWT_SHA256_ARM64="2a282e3edda7be17f092ac58aff0ec6dac9ddd152a642e8e61e6d625f2abe696"
ENV HEALTH_FILE=/tmp/healthy

ARG BUILD_ARCH
RUN \
    if [ "$BUILD_ARCH" = "aarch64" ]; then \
      DOWNLOAD_URL="https://github.com/fosrl/newt/releases/download/${NEWT_VERSION#v}/newt_linux_arm64"; \
      EXPECTED_SHA="${NEWT_SHA256_ARM64}"; \
    elif [ "$BUILD_ARCH" = "amd64" ]; then \
      DOWNLOAD_URL="https://github.com/fosrl/newt/releases/download/${NEWT_VERSION#v}/newt_linux_amd64"; \
      EXPECTED_SHA="${NEWT_SHA256_AMD64}"; \
    else \
      echo "Unsupported architecture: ${BUILD_ARCH}" >&2; exit 1; \
    fi \
    && curl --proto '=https' --tlsv1.2 --retry 3 --retry-delay 2 --fail --silent --show-error \
         -L -o /newt "$DOWNLOAD_URL" \
    && if [ -z "$EXPECTED_SHA" ]; then \
         echo "No SHA256 configured for ${BUILD_ARCH}; refusing unverified binary" >&2; exit 1; \
       fi \
    && echo "${EXPECTED_SHA}  /newt" | sha256sum -c - \
    && chmod a+x /newt

COPY run.sh /
RUN chmod a+x /run.sh

# Newt writes HEALTH_FILE when the tunnel is up and removes it when the
# connection is lost. start-period gives the tunnel time to come up.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=60s \
  CMD test -f "${HEALTH_FILE}" || exit 1

CMD ["/run.sh"]
