ARG DEBIAN_VERSION="12.12"

FROM debian:${DEBIAN_VERSION}-slim AS base
ENV DEBIAN_FRONTEND=noninteractive

ARG PROXMARK3_PACKAGE_EXTRAS="libbluetooth-dev qtbase5-dev libpython3-dev libgd-dev"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends sudo libreadline-dev libnewlib-dev libbz2-dev liblz4-dev libssl-dev ${PROXMARK3_PACKAGE_EXTRAS} && \
    apt-get clean

ENV PATH="$PATH:/proxmark3"


FROM base AS build

ENV LANG=C

RUN apt-get install -y --no-install-recommends git ca-certificates build-essential pkg-config gcc-arm-none-eabi && \
    apt-get clean

COPY proxmark3 /proxmark3
WORKDIR /proxmark3

ARG PROXMARK3_PLATFORM="PM3RDV4"
ARG PROXMARK3_PLATFORM_EXTRAS=""

RUN make clean && make -j PLATFORM=${PROXMARK3_PLATFORM} PLATFORM_EXTRAS="${PROXMARK3_PLATFORM_EXTRAS}"


FROM base AS prefs

COPY --from=build /proxmark3 /proxmark3
RUN pm3 --offline -c "prefs set savepaths --def /saves; prefs set savepaths --dump /saves; prefs set savepaths --trace /saves; prefs set color --ansi; prefs set emoji --emoji"


FROM base AS image

ARG USER_NAME=proxmark3
ARG GROUP_NAME=proxmark3

ARG UID=1000
ARG GID=1000

ENV UID=${UID} USER_NAME=${USER_NAME} GID=${GID} GROUP_NAME=${GROUP_NAME}

RUN groupadd --gid ${GID} ${GROUP_NAME} && \
    useradd --create-home --shell /bin/bash --uid ${UID} --gid ${GID} --groups dialout ${USER_NAME}

COPY --from=build /proxmark3 /proxmark3
COPY --from=prefs --chown=${USER_NAME}:${GROUP_NAME} /root/.proxmark3/preferences.json /home/${USER_NAME}/.proxmark3/

RUN mkdir /saves && \
    chown ${USER_NAME}:${GROUP_NAME} /saves

VOLUME ["/saves", "/home/${USER_NAME}/.proxmark3"]
COPY entrypoint /entrypoint

ENTRYPOINT ["/entrypoint"]
CMD ["pm3"]
