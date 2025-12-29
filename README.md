# Radarr Distroless

Kubernetes-native distroless Docker image for [Radarr](https://github.com/Radarr/Radarr).

## Features

- Distroless base (no shell, minimal attack surface)
- Kubernetes-native permissions (no s6-overlay)
- Read-only root filesystem
- Non-root execution
- Minimal image size (~100MB vs ~500MB)

## Usage

### Docker

```bash
docker run -d \
  --name radarr \
  -p 7878:7878 \
  -v /path/to/config:/config \
  ghcr.io/runlix/radarr-distroless:release
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: radarr
spec:
  template:
    spec:
      containers:
      - name: radarr
        image: ghcr.io/runlix/radarr-distroless:release
        ports:
        - containerPort: 7878
        volumeMounts:
        - name: config
          mountPath: /config
        securityContext:
          runAsUser: 1012
          runAsGroup: 1011
          supplementalGroups: [1010, 1003]
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: radarr-config
      securityContext:
        fsGroup: 1011
```

## Tags

See [tags.json](tags.json) for available tags.

## Environment Variables

- `RADARR__SERVER__PORT`: Server port (default: 7878)

## License

GPL-3.0
