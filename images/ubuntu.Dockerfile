ARG UBUNTU_VERSION=resolute

FROM ubuntu:${UBUNTU_VERSION}

ARG KWIN_URL
ARG XWAYLAND_URL
ARG MESA_URL

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    : "${KWIN_URL:?KWIN_URL must be provided}"; \
    : "${XWAYLAND_URL:?XWAYLAND_URL must be provided}"; \
    : "${MESA_URL:?MESA_URL must be provided}"; \
    apt update; \
    apt install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus-x11 \
        dolphin \
        kde-plasma-desktop \
        konsole \
        kwin-wayland \
        libegl-mesa0 \
        libgbm1 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        mesa-libgallium \
        mesa-vulkan-drivers \
        plasma-session-wayland \
        psmisc \
        sudo \
        unzip \
        xwayland; \
    curl --fail --location --show-error --output /tmp/xwayland.deb "${XWAYLAND_URL}"; \
    apt reinstall -y --allow-downgrades /tmp/xwayland.deb; \
    curl --fail --location --show-error --output /tmp/kwin.zip "${KWIN_URL}"; \
    mkdir -p /tmp/kwin-debs-install; \
    unzip -q /tmp/kwin.zip -d /tmp/kwin-debs-install; \
    test -n "$(find /tmp/kwin-debs-install -type f -name '*.deb' -print -quit)"; \
    find /tmp/kwin-debs-install -type f -name '*.deb' \
        -exec apt reinstall -y --allow-downgrades {} +; \
    curl --fail --location --show-error --output /tmp/mesa.tar.gz "${MESA_URL}"; \
    tar -zxvf /tmp/mesa.tar.gz -C /; \
    apt-mark hold \
        xwayland \
        kwin-common \
        kwin-data \
        kwin-wayland \
        libkwin6 \
        libegl-mesa0 \
        libgbm1 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        mesa-libgallium \
        mesa-vulkan-drivers; \
    apt clean; \
    rm -rf \
        /tmp/xwayland.deb \
        /tmp/kwin.zip \
        /tmp/kwin-debs-install \
        /tmp/mesa.tar.gz \
        /var/lib/apt/lists/*

RUN install -d -m 0755 /opt/lfdevs/anland

COPY --chmod=0755 scripts/startplasma-anland.sh /opt/lfdevs/anland/startplasma-anland

RUN printf '%s\n' 'export PATH="/opt/lfdevs/anland:${PATH}"' \
    > /etc/profile.d/anland-path.sh \
    && chmod 0644 /etc/profile.d/anland-path.sh

ENV PATH="/opt/lfdevs/anland:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
