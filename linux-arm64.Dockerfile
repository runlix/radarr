# Builder tag from VERSION.json builder.tag (e.g., "bookworm-slim")
ARG BUILDER_TAG=bookworm-slim
# Base tag (variant-arch) from VERSION.json base.tag (e.g., "release-2025.12.29.1-linux-arm64-latest")
ARG BASE_TAG=release-2025.12.29.1-linux-arm64-latest
# Selected digests (build script will set based on target configuration)
# Default to empty string - build script should always provide valid digests
# If empty, FROM will fail (which is desired to enforce digest pinning)
ARG BUILDER_DIGEST=""
ARG BASE_DIGEST=""
# Package URL from VERSION.json packages[0].url
ARG PACKAGE_URL=""

# STAGE 1 — fetch Radarr binaries
# Build script will pass BUILDER_TAG and BUILDER_DIGEST from VERSION.json
# Format: debian:bookworm-slim@sha256:digest (when digest provided)
FROM docker.io/library/debian:${BUILDER_TAG}@${BUILDER_DIGEST} AS fetch

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

# STAGE 2 — install Radarr-specific runtime packages
# Build script will pass BUILDER_TAG and BUILDER_DIGEST from VERSION.json
FROM docker.io/library/debian:${BUILDER_TAG}@${BUILDER_DIGEST} AS radarr-deps

# Use BuildKit cache mounts to persist apt cache between builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    ffmpeg \
    mediainfo \
 && rm -rf /var/lib/apt/lists/*

# STAGE 3 — distroless final image
# Build script will pass BASE_TAG (from VERSION.json base.tag) and BASE_DIGEST
# Format: ghcr.io/runlix/distroless-runtime:release-2025.12.29.1-linux-arm64-latest@sha256:digest (when digest provided)
FROM ghcr.io/runlix/distroless-runtime:${BASE_TAG}@${BASE_DIGEST}

# Hardcoded for arm64 - no conditionals needed!
ARG LIB_DIR=aarch64-linux-gnu
ARG LD_SO=ld-linux-aarch64.so.1

COPY --from=fetch /app /app
# Copy binaries from radarr-deps stage (kept separate for clarity)
COPY --from=radarr-deps /usr/bin/sqlite3 /usr/bin/sqlite3
COPY --from=radarr-deps /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=radarr-deps /usr/bin/mediainfo /usr/bin/mediainfo
# Copy shared libraries - combined into fewer layers by grouping related libraries
# SQLite libraries
COPY --from=radarr-deps /usr/lib/${LIB_DIR}/libsqlite3.so.* /usr/lib/${LIB_DIR}/
# FFmpeg libraries (avcodec, avformat, avutil, swscale)
COPY --from=radarr-deps /usr/lib/${LIB_DIR}/libavcodec.so.* \
                        /usr/lib/${LIB_DIR}/libavformat.so.* \
                        /usr/lib/${LIB_DIR}/libavutil.so.* \
                        /usr/lib/${LIB_DIR}/libswscale.so.* \
                        /usr/lib/${LIB_DIR}/
# MediaInfo libraries (mediainfo, zen)
COPY --from=radarr-deps /usr/lib/${LIB_DIR}/libmediainfo.so.* \
                        /usr/lib/${LIB_DIR}/libzen.so.* \
                        /usr/lib/${LIB_DIR}/

WORKDIR /app/bin
USER 65532:65532
ENTRYPOINT ["/app/bin/Radarr", "-nobrowser", "-data=/config"]

