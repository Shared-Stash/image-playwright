# syntax=docker/dockerfile:1.7
#
# bitsnbites/playwright — hardened Playwright image for GitHub Actions
#
# Built nightly. Tagged as <playwright-version>-node<node-major>, e.g. 1.59-node24.
# `latest` points at newest-supported Playwright x newest-LTS-Node.
#
# Designed to remove the slowest steps from React/Angular/Node CI:
#   - `npx playwright install`        (~40-60s)  -> browsers preinstalled
#   - `npx playwright install-deps`   (~30s+)    -> system libs preinstalled
#   - global package manager installs (~10-20s)  -> pnpm + yarn preinstalled
#   - native module build deps        (~10s)     -> python3/make/g++ preinstalled

ARG NODE_MAJOR=24
ARG PLAYWRIGHT_VERSION=1.59.1

# We *want* :latest here. The point of the nightly build is to pick up
# fresh CVE patches in the Chainguard base. The skip-build gate uses the
# resolved base digest as part of its hash, so a base update forces a
# rebuild — this is a feature, not a bug.
# hadolint ignore=DL3007
FROM cgr.dev/chainguard/wolfi-base:latest

ARG NODE_MAJOR
ARG PLAYWRIGHT_VERSION
ARG BUILD_DATE
ARG VCS_REF

# OCI labels — used both for discoverability and by the skip-build gate
# (the nightly workflow reads org.bitsnbites.build-hash off the previously
# pushed manifest to decide whether anything has changed).
LABEL org.opencontainers.image.title="bitsnbites/playwright" \
      org.opencontainers.image.description="Hardened Playwright image for GitHub Actions CI (tests + builds, not deploys)." \
      org.opencontainers.image.source="https://github.com/bitsnbites/playwright-action-image" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="bitsnbites" \
      org.opencontainers.image.base.name="cgr.dev/chainguard/wolfi-base:latest" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.bitsnbites.node.major="${NODE_MAJOR}" \
      org.bitsnbites.playwright.version="${PLAYWRIGHT_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    CI=true \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PNPM_HOME=/usr/local/share/pnpm \
    PATH=/usr/local/share/pnpm:$PATH \
    NODE_ENV=development

# 1. Core toolchain + package managers + browser system deps
#    Wolfi uses apk; package names below are the Wolfi/Alpine equivalents
#    of the deps Microsoft installs via `playwright install-deps` on Debian.
USER root
# Intentionally NOT pinning apk versions. This image is rebuilt nightly
# specifically to pick up the latest patched packages from the Chainguard
# repos. Pinning every package would invert the security posture.
# hadolint ignore=DL3018
RUN apk update && apk add --no-cache \
      # core CLI / CI tooling
      bash coreutils findutils grep sed gawk \
      git curl jq ca-certificates tzdata \
      # native module build chain
      python-3 py3-pip make gcc g++ pkgconf \
      # node + npm (matches NODE_MAJOR if available; otherwise newest in repo)
      "nodejs-${NODE_MAJOR}" npm \
      # font + rendering libs (chromium / firefox / webkit common)
      font-noto font-noto-emoji font-noto-cjk fontconfig freetype \
      libstdc++ libgcc glibc-locale-en \
      # X / GL / wayland / GTK runtime libs needed by browsers
      libnss libnspr libatk-1.0 libatk-bridge-2.0 cups-libs \
      libxkbcommon libxcomposite libxdamage libxfixes libxrandr \
      libxshmfence mesa-gbm mesa-egl mesa-gles \
      pango cairo libdrm \
      libwayland-client libwayland-server libwayland-egl libwayland-cursor \
      gtk3 gtk-4.0 \
      alsa-lib at-spi2-core at-spi2-atk libxss \
      # webkit-specific
      gstreamer gst-plugins-base harfbuzz-icu libwebp libsecret libhyphen \
      libevent enchant2 libmanette libgudev libavif libxslt \
      libsoup-3 woff2 \
      # firefox-specific
      dbus-glib \
    && rm -rf /var/cache/apk/*

# 2. Global JS package managers
RUN npm install -g --no-audit --no-fund \
      "pnpm@latest" \
      "yarn@1.22.x"

# 3. Playwright + browsers (pinned)
#    Install playwright globally so `npx playwright` works without a local
#    install, and run `playwright install` (NOT --with-deps; we already
#    installed deps via apk above, since playwright's own --with-deps is
#    Debian-only and would fail on Wolfi).
RUN npm install -g --no-audit --no-fund \
      "playwright@${PLAYWRIGHT_VERSION}" \
      "@playwright/test@${PLAYWRIGHT_VERSION}" \
    && mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}" \
    && playwright install chromium firefox webkit \
    && chmod -R a+rx "${PLAYWRIGHT_BROWSERS_PATH}"

# 4. User for CI safety
#    GitHub Actions container jobs need root inside the container so the
#    runner can chown the workspace mount. Running as non-root would force
#    every consuming workflow to add an explicit `options: --user 0`. We
#    accept the hadolint warning here intentionally.
# hadolint ignore=DL3002
USER root
WORKDIR /workspace

# Quick smoke test baked into the image: fail the build if any of the
# headline tools are missing or broken.
RUN node --version \
    && npm --version \
    && pnpm --version \
    && yarn --version \
    && git --version \
    && playwright --version

# Default command: drop to bash. GitHub Actions overrides this.
CMD ["bash"]
