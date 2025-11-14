ARG DEBIAN_VERSION="12.12"

FROM debian:${DEBIAN_VERSION}-slim AS base
ENV DEBIAN_FRONTEND=noninteractive

ARG PROXMARK3_PACKAGE_EXTRAS="libbluetooth-dev qtbase5-dev libpython3-dev libgd-dev"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends libreadline-dev libnewlib-dev libbz2-dev liblz4-dev libssl-dev ${PROXMARK3_PACKAGE_EXTRAS} && \
    apt-get clean


FROM base AS build

ENV LANG=C

RUN apt-get install -y --no-install-recommends git ca-certificates build-essential pkg-config gcc-arm-none-eabi && \
    apt-get clean

COPY proxmark3 /proxmark3
WORKDIR /proxmark3

ARG PROXMARK3_PLATFORM="PM3RDV4"
ARG PROXMARK3_PLATFORM_EXTRAS=""

RUN make clean && make -j PLATFORM=${PROXMARK3_PLATFORM} PLATFORM_EXTRAS="${PROXMARK3_PLATFORM_EXTRAS}"
# RUN make install DESTDIR=build
ENV PATH="$PATH:/proxmark3"

# FROM base AS image

RUN pm3 --offline -c "prefs set savepaths --create --def $HOME/proxmark3"

# COPY --from=build /proxmark3/build/usr/local/bin/proxmark3 /proxmark3/build/usr/local/bin/pm3* /usr/local/bin/
# COPY --from=build /proxmark3/build/usr/local/share/proxmark3/* /usr/local/share/proxmark3/
# COPY --from=build /proxmark3/build/etc/udev/rules.d/77-pm3-usb-device-blacklist.rules /etc/udev/rules.d/

CMD ["pm3"]
