ARG BUILDER_REF="docker.io/library/debian:bookworm-slim@sha256:26d52380dd92c79effe0f36c1316855b3bbf67909fd1d72bd36e2933ae1f0486"
ARG BASE_REF="ghcr.io/runlix/distroless-runtime-v2-canary:stable@sha256:77f225cc62e8aa2cf6807434f112830cdcd186f1145fbf10f0283adb4ee39baf"
ARG PACKAGE_URL="https://github.com/Radarr/Radarr/releases/download/v6.1.1.10360/Radarr.master.6.1.1.10360.linux-core-arm64.tar.gz"

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

# Hardcoded for arm64 - no conditionals needed!
ARG LIB_DIR=aarch64-linux-gnu
ARG LD_SO=ld-linux-aarch64.so.1

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
