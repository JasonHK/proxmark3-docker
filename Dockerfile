ARG DEBIAN_VERSION="12.12"

FROM debian:${DEBIAN_VERSION}-slim AS base
ENV DEBIAN_FRONTEND=noninteractive

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

ENV LANG=C

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

ARG PROXMARK3_PLATFORM="PM3RDV4"
ARG PROXMARK3_PLATFORM_EXTRAS=""

RUN set -eux; \
    make clean; \
    make -j; \
    make install DESTDIR=build PREFIX=/usr UDEV_PREFIX=/lib/udev/rules.d; \
    make -j fullimage PLATFORM=PM3GENERIC; \
    make fullimage/install PLATFORM=PM3GENERIC DESTDIR=build PREFIX=/usr FWTAG=generic; \
    make -j fullimage PLATFORM=PM3ICOPYX; \
    make fullimage/install PLATFORM=PM3ICOPYX DESTDIR=build PREFIX=/usr FWTAG=icopyx; \
    make -j fullimage PLATFORM=PM3ULTIMATE; \
    make fullimage/install PLATFORM=PM3ULTIMATE DESTDIR=build PREFIX=/usr FWTAG=ultimate; \
    make -j fullimage PLATFORM="${PROXMARK3_PLATFORM}" PLATFORM_EXTRAS="${PROXMARK3_PLATFORM_EXTRAS}"; \
    make fullimage/install PLATFORM="${PROXMARK3_PLATFORM}" PLATFORM_EXTRAS="${PROXMARK3_PLATFORM_EXTRAS}" DESTDIR=build PREFIX=/usr FWTAG=custom


FROM base AS build

COPY --from=builder /proxmark3/build/usr/bin/proxmark3 /proxmark3/build/usr/bin/pm3* /usr/bin/
COPY --from=builder /proxmark3/build/usr/share/proxmark3/ /usr/share/proxmark3/
COPY --from=builder /proxmark3/build/lib/udev/rules.d/77-pm3-usb-device-blacklist.rules /lib/udev/rules.d/

COPY --chmod=775 scripts/pm3-firmwares /usr/bin/


FROM build AS prefs

RUN set -eux; \
    pm3 --offline -c "prefs set savepaths --def /proxmark/saves; prefs set savepaths --dump /proxmark/saves; prefs set savepaths --trace /proxmark/saves; prefs set color --ansi; prefs set emoji --emoji"


FROM build AS image

RUN set -eux; \
    apt-get install -y --no-install-recommends \
        gosu \
        tini; \
    rm -rf /var/lib/apt/lists/*; \
    gosu nobody true

ARG USER_NAME=proxmark3
ARG GROUP_NAME=proxmark3

ARG UID=1000
ARG GID=1000

ENV UID=${UID} USER_NAME=${USER_NAME} GID=${GID} GROUP_NAME=${GROUP_NAME}

RUN set -eux; \
    groupadd --gid ${GID} proxmark; \
    useradd -m -u ${UID} -g ${GID} -G dialout -d /proxmark -s /bin/bash proxmark; \
    mkdir -p /proxmark/saves

COPY --from=prefs --chown=proxmark:proxmark /root/.proxmark3/preferences.json /root/.proxmark3/
COPY scripts/proxmark3-docker /root/

VOLUME ["/proxmark/saves", "/proxmark/.proxmark3"]

WORKDIR /proxmark
ENTRYPOINT ["tini", "--", "/root/proxmark3-docker"]
CMD ["pm3"]
