ARG DEBIAN_VERSION="12.12"

FROM debian:${DEBIAN_VERSION}-slim AS base
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends sudo libreadline-dev libnewlib-dev libbz2-dev liblz4-dev libssl-dev libbluetooth-dev qtbase5-dev libpython3-dev libgd-dev && \
    apt-get clean

# ENV PATH="$PATH:/proxmark3"


FROM base AS builder

ENV LANG=C

RUN apt-get install -y --no-install-recommends git ca-certificates build-essential pkg-config gcc-arm-none-eabi && \
    apt-get clean

COPY proxmark3 /proxmark3
WORKDIR /proxmark3

ARG PROXMARK3_PLATFORM="PM3RDV4"
ARG PROXMARK3_PLATFORM_EXTRAS=""

RUN make clean && \
    make -j && \
    make install DESTDIR=build PREFIX=/usr UDEV_PREFIX=/lib/udev/rules.d && \
    make -j fullimage PLATFORM=PM3GENERIC && \
    make fullimage/install PLATFORM=PM3GENERIC DESTDIR=build PREFIX=/usr FWTAG=generic && \
    make -j fullimage PLATFORM=PM3ICOPYX && \
    make fullimage/install PLATFORM=PM3ICOPYX DESTDIR=build PREFIX=/usr FWTAG=icopyx && \
    make -j fullimage PLATFORM=PM3ULTIMATE && \
    make fullimage/install PLATFORM=PM3ULTIMATE DESTDIR=build PREFIX=/usr FWTAG=ultimate && \
    make -j fullimage PLATFORM="${PROXMARK3_PLATFORM}" PLATFORM_EXTRAS="${PROXMARK3_PLATFORM_EXTRAS}" && \
    make fullimage/install PLATFORM="${PROXMARK3_PLATFORM}" PLATFORM_EXTRAS="${PROXMARK3_PLATFORM_EXTRAS}" DESTDIR=build PREFIX=/usr FWTAG=custom


FROM base AS build

COPY --from=builder /proxmark3/build/usr/bin/proxmark3 /proxmark3/build/usr/bin/pm3* /usr/bin/
COPY --from=builder /proxmark3/build/usr/share/proxmark3/* /usr/share/proxmark3/
COPY --from=builder /proxmark3/build/lib/udev/rules.d/77-pm3-usb-device-blacklist.rules /lib/udev/rules.d/


FROM build AS prefs

RUN pm3 --offline -c "prefs set savepaths --def /proxmark3/saves; prefs set savepaths --dump /proxmark3/saves; prefs set savepaths --trace /proxmark3/saves; prefs set color --ansi; prefs set emoji --emoji"


FROM build AS image

ARG USER_NAME=proxmark3
ARG GROUP_NAME=proxmark3

ARG UID=1000
ARG GID=1000

ENV UID=${UID} USER_NAME=${USER_NAME} GID=${GID} GROUP_NAME=${GROUP_NAME}

RUN groupadd --gid ${GID} ${GROUP_NAME} && \
    useradd -m -u ${UID} -g ${GID} -G dialout -d /proxmark3 -s /bin/bash ${USER_NAME} && \
    mkdir -p /proxmark3/saves

COPY --from=prefs --chown=${USER_NAME}:${GROUP_NAME} /root/.proxmark3/preferences.json /root/.proxmark3/
COPY proxmark3-docker /root/

VOLUME ["/proxmark3/saves", "/proxmark3/.proxmark3"]

WORKDIR /proxmark3
ENTRYPOINT ["/root/proxmark3-docker"]
CMD ["pm3"]
