# Public amd64 Ubuntu 24.04 + precompiled Wine 11.0. Pin the verified image,
# rather than following its mutable latest tag. No proprietary SDK is copied.
ARG BASE_IMAGE=scottyhardy/docker-wine@sha256:5a2b4179c125cc28c1ffcfeea6f3e3f678fd5caddcc8b601258fd1b6e755c995
FROM ${BASE_IMAGE}

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=30 \
    && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl dos2unix gh git \
        msitools ninja-build patch perl python3 tar unzip zstd \
        libicu74 libssl3t64 libgtk-3-0t64 libnss3 libxss1 \
        libasound2t64 libgbm1 libvulkan1 libunwind8 libcurl4t64 \
        xvfb xauth \
    && rm -rf /var/lib/apt/lists/*

# Do not launch the base image's remote-desktop/audio services. The host launcher
# chooses a non-root UID/GID and supplies all project/toolchain bind mounts.
ENTRYPOINT ["/bin/bash"]
