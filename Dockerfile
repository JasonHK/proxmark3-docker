ARG DEBIAN_VERSION="12.12"

FROM debian:${DEBIAN_VERSION}-slim AS base

ARG DEBIAN_FRONTEND=noninteractive

# Install common packages
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get dist-upgrade -y; \
    apt-get install -y --no-install-recommends \
        libbluetooth-dev \
        libbz2-dev \
        libgd-dev \
        liblz4-dev \
        libnewlib-dev \
        libpython3-dev \
        libreadline-dev \
        libssl-dev \
        qtbase5-dev


FROM base AS builder

ARG DEBIAN_FRONTEND=noninteractive

# Install packages for compiling
RUN set -eux; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        gcc-arm-none-eabi \
        git \
        pkg-config; \
    rm -rf /var/lib/apt/lists/*

COPY proxmark3 /proxmark3
WORKDIR /proxmark3

ARG PROXMARK3_CUSTOM_PLATFORM=""
ARG PROXMARK3_CUSTOM_PLATFORM_EXTRAS=""

RUN set -eux; \
    make clean; \
    \
    # Full build with firmware for Proxmark3 RDV4
    make -j; \
    make install DESTDIR=build PREFIX=/usr UDEV_PREFIX=/lib/udev/rules.d; \
    \
    # Firmware for generic Proxmark3
    make -j fullimage PLATFORM=PM3GENERIC; \
    make fullimage/install PLATFORM=PM3GENERIC DESTDIR=build PREFIX=/usr FWTAG=generic; \
    \
    # Firmware for iCopy-X with XC3S100E
    make -j fullimage PLATFORM=PM3ICOPYX; \
    make fullimage/install PLATFORM=PM3ICOPYX DESTDIR=build PREFIX=/usr FWTAG=icopyx; \
    \
    # Firmware for Proxmark3 Ultimate with XC2S50
    make -j fullimage PLATFORM=PM3ULTIMATE; \
    make fullimage/install PLATFORM=PM3ULTIMATE DESTDIR=build PREFIX=/usr FWTAG=ultimate; \
    \
    # Firmware for custom platform (optional)
    if [ -n "${PROXMARK3_CUSTOM_PLATFORM}" ]; then \
        make -j fullimage PLATFORM="${PROXMARK3_CUSTOM_PLATFORM}" PLATFORM_EXTRAS="${PROXMARK3_CUSTOM_PLATFORM_EXTRAS}"; \
        make fullimage/install PLATFORM="${PROXMARK3_CUSTOM_PLATFORM}" PLATFORM_EXTRAS="${PROXMARK3_CUSTOM_PLATFORM_EXTRAS}" DESTDIR=build PREFIX=/usr FWTAG=custom; \
    fi


FROM base AS build

COPY --from=builder /proxmark3/build/usr/bin/proxmark3 /proxmark3/build/usr/bin/pm3* /usr/bin/
COPY --from=builder /proxmark3/build/usr/share/proxmark3/ /usr/share/proxmark3/
COPY --from=builder /proxmark3/build/lib/udev/rules.d/77-pm3-usb-device-blacklist.rules /lib/udev/rules.d/

COPY --chmod=775 scripts/pm3-firmwares /usr/bin/


FROM build AS prefs

ARG DEBIAN_FRONTEND=noninteractive

# Generate default preferences
RUN set -eux; \
    pm3 --offline -c "prefs set savepaths --def /proxmark/saves; prefs set savepaths --dump /proxmark/saves; prefs set savepaths --trace /proxmark/saves; prefs set color --ansi; prefs set emoji --emoji"


FROM build AS image

ARG DEBIAN_FRONTEND=noninteractive

ARG GOSU_VERSION=1.14-1+b10
ARG TINI_VERSION=0.19.0-1+b3

# Install packages for the final image
RUN set -eux; \
    apt-get install -y --no-install-recommends \
        gosu=${GOSU_VERSION} \
        tini=${TINI_VERSION}; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # Validate the installation of gosu
    gosu nobody true

ENV UID=1000 \
    GID=1000

# Prepare the non-root user
RUN set -eux; \
    groupadd --gid ${GID} proxmark; \
    useradd -m -u ${UID} -g ${GID} -G dialout -d /proxmark -s /bin/bash proxmark; \
    mkdir -p /proxmark/saves

COPY --from=prefs --chmod=655 /root/.proxmark3/preferences.json /etc/proxmark3/
COPY --chmod=555 scripts/proxmark3-docker /root/

VOLUME ["/proxmark/saves", "/proxmark/.proxmark3"]

WORKDIR /proxmark
ENTRYPOINT ["tini", "--", "/root/proxmark3-docker"]
CMD ["pm3"]
