ARG BUILDER_REF="docker.io/library/debian:bookworm-slim@sha256:5a2a80d11944804c01b8619bc967e31801ec39bf3257ab80b91070eb23625644"
ARG BASE_REF="ghcr.io/runlix/distroless-runtime-v2-canary:stable@sha256:a39da96f68c2145594b573baeed3858c9f032e186997efdba9a005cc79563cb9"
ARG PACKAGE_URL="https://github.com/Radarr/Radarr/releases/download/v6.1.1.10360/Radarr.master.6.1.1.10360.linux-core-x64.tar.gz"

FROM ${BUILDER_REF} AS fetch

# Redeclare ARG in this stage so it's available for use in RUN commands
ARG PACKAGE_URL

WORKDIR /app

# Use BuildKit cache mounts to persist apt cache between builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/bin \
 && curl -L -f "${PACKAGE_URL}" -o radarr.tar.gz \
 && tar -xzf radarr.tar.gz -C /app/bin --strip-components=1 \
 && chmod +x /app/bin/Radarr \
 && rm radarr.tar.gz

FROM ${BUILDER_REF} AS radarr-deps

# Use BuildKit cache mounts to persist apt cache between builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    ffmpeg \
    mediainfo \
 && rm -rf /var/lib/apt/lists/*

FROM ${BASE_REF}

# Hardcoded for amd64 - no conditionals needed!
ARG LIB_DIR=x86_64-linux-gnu
ARG LD_SO=ld-linux-x86-64.so.2

COPY --from=fetch /app /app
COPY --from=radarr-deps /usr/bin/sqlite3 /usr/bin/sqlite3
COPY --from=radarr-deps /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=radarr-deps /usr/bin/mediainfo /usr/bin/mediainfo
COPY --from=radarr-deps /usr/lib/${LIB_DIR}/libsqlite3.so.* /usr/lib/${LIB_DIR}/
COPY --from=radarr-deps /usr/lib/${LIB_DIR}/libavcodec.so.* \
                        /usr/lib/${LIB_DIR}/libavformat.so.* \
                        /usr/lib/${LIB_DIR}/libavutil.so.* \
                        /usr/lib/${LIB_DIR}/libswscale.so.* \
                        /usr/lib/${LIB_DIR}/
COPY --from=radarr-deps /usr/lib/${LIB_DIR}/libmediainfo.so.* \
                        /usr/lib/${LIB_DIR}/libzen.so.* \
                        /usr/lib/${LIB_DIR}/

WORKDIR /app/bin
USER 65532:65532
ENTRYPOINT ["/app/bin/Radarr", "-nobrowser", "-data=/config"]
