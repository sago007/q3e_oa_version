# Build the OpenArena compatible Quake3e binaries (Linux x86_64 + Windows
# x86_64) in a clean Ubuntu 22.04 container and export dist/ to the host:
#
#   DOCKER_BUILDKIT=1 docker build -o dist-docker .
#
# Options (docker build --build-arg NAME=VALUE):
#   QUAKE3E_COMMIT   override the pinned upstream commit from build.sh
#   JOBS             parallel make jobs (default: all cores)
#   BUILD_ARGS       extra build.sh options, e.g. "--linux-only"
#
# `--target build` gives an image with the toolchain and the full build tree
# in /src for debugging.

FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
# libz-mingw-w64-dev is deliberately not installed: its libz.dll.a would be
# linked in preference to a static libz.a and the Windows exe would then need
# zlib1.dll. build.sh builds a static mingw zlib itself instead (needs curl).
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git make pkg-config ca-certificates curl \
        libsdl2-dev libcurl4-openssl-dev \
        gcc-mingw-w64-x86-64 binutils-mingw-w64-x86-64 \
    && rm -rf /var/lib/apt/lists/*

# git am creates commits and needs a committer identity.
ENV GIT_COMMITTER_NAME=build GIT_COMMITTER_EMAIL=build@localhost

WORKDIR /src
COPY build.sh ./
COPY patches/ patches/

ARG QUAKE3E_COMMIT
ARG JOBS
ARG BUILD_ARGS
RUN ./build.sh --jobs "${JOBS:-$(nproc)}" ${BUILD_ARGS}

# Final stage holds only the binaries, so `docker build -o <dir> .` writes
# dist/linux-x86_64 and dist/windows-x86_64 straight to the host.
FROM scratch AS dist
COPY --from=build /src/dist/ /
