# Shared amd64 toolchain image. Keep this image private: it includes MSVC/SDK
# and Wwise binaries. Credentials are supplied only through BuildKit secrets.
ARG BASE_IMAGE=scottyhardy/docker-wine@sha256:5a2b4179c125cc28c1ffcfeea6f3e3f678fd5caddcc8b601258fd1b6e755c995
FROM ${BASE_IMAGE} AS base

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=30 \
    && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl dos2unix gh git \
        msitools ninja-build patch perl python3 rsync tar unzip zstd \
        libicu74 libssl3t64 libgtk-3-0t64 libnss3 libxss1 \
        libasound2t64 libgbm1 libvulkan1 libunwind8 libcurl4t64 \
        xvfb xauth \
    && rm -rf /var/lib/apt/lists/*

# Do not launch the base image's remote-desktop/audio services. The host launcher
# chooses a non-root UID/GID and supplies all project/toolchain bind mounts.
ENTRYPOINT ["/bin/bash"]

FROM base AS msvc
COPY install-msvc.sh /opt/cartograph/install-msvc.sh
RUN --mount=type=cache,target=/var/cache/cartograph-msvc \
    bash /opt/cartograph/install-msvc.sh

FROM base AS wwise
COPY install-wwise.sh /opt/cartograph/install-wwise.sh
RUN --mount=type=secret,id=WWISE_EMAIL,required=true \
    --mount=type=secret,id=WWISE_PASSWORD,required=true \
    bash /opt/cartograph/install-wwise.sh

FROM base AS toolchain
COPY --from=msvc /opt/cartograph/msvc /opt/cartograph/msvc
COPY --from=wwise /opt/cartograph/wwise-plugins /opt/cartograph/wwise-plugins
COPY --from=wwise /usr/local/bin/wwise-cli /usr/local/bin/wwise-cli
ENV UE_WINE_MSVC=/opt/cartograph/msvc
LABEL org.opencontainers.image.description="Cartograph Wine/MSVC/Windows SDK/Wwise build toolchain"
