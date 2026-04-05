# Radarr

`radarr` publishes the Runlix container image for [Radarr](https://github.com/Radarr/Radarr).

The current published image name is:

```text
ghcr.io/runlix/radarr
```

Use a versioned stable manifest tag from [release.json](release.json):

```dockerfile
FROM ghcr.io/runlix/radarr:<version>-stable
```

The authoritative published tags, digests, and source revision live in [release.json](release.json).

## What’s Included

- Radarr upstream binaries
- `sqlite3`
- `ffmpeg`
- `mediainfo`
- shared runtime libraries from `distroless-runtime-v2-canary`

The image keeps the distroless runtime model while layering in the Radarr-specific binaries and media tooling it needs.

## Branch Layout

`main` owns metadata and automation config:

- `README.md`
- `links.json`
- `release.json`
- `renovate.json`
- `.github/workflows/validate-release-metadata.yml`

`release` owns build and publish inputs:

- `.ci/build.json`
- `.ci/smoke-test.sh`
- `linux-*.Dockerfile`
- `.github/workflows/validate-build.yml`
- `.github/workflows/publish-release.yml`

## Release Flow

Changes merge to `release`, where `Publish Release` builds the versioned `stable` and `debug` multi-arch manifests, attests them, optionally sends Telegram, and opens the sync PR back to `main`.

`main` validates metadata and config-only changes with `Validate Release Metadata`.

## Environment Variables

- `RADARR__SERVER__PORT`: server port, default `7878`

## License

GPL-3.0
