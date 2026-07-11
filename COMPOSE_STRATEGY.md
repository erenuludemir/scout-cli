# Docker Compose Strategy

This repository contains several independent Compose lanes. Do not merge every
Compose file together. Select the lane that matches the service being operated.

## File Hierarchy

The supported files are organized as independent root API, core gateway, MCAI,
USDT v2, ManagerAI, runtime, monitoring, and compatibility lanes. The file list
used for `config` must be the same list used for `up`.

## File Descriptions

### Root Python API

`docker-compose.yml` builds the root Flask application from `Dockerfile` and
publishes it on `127.0.0.1:${HOST_PORT:-5003}`. This is the smallest application
smoke-test lane.

```bash
docker compose -f docker-compose.yml config --quiet
docker compose -f docker-compose.yml up --build
```

### Core Gateway Stack

`compose.yml` contains `dex`, `redis`, `quantumai-usdt`, and `gateway`. All four
services share the named `mcai_net` network. Gateway starts only after its two
HTTP dependencies are healthy.

```bash
docker compose -f compose.yml config --quiet
docker compose -f compose.yml up --build
```

For the supported development overrides:

```bash
docker compose \
  -f compose.yml \
  -f docker-compose.base.yml \
  -f compose.override.yml \
  -p quantumai-stack \
  config --quiet

docker compose \
  -f compose.yml \
  -f docker-compose.base.yml \
  -f compose.override.yml \
  -p quantumai-stack \
  up --build
```

`docker-compose.base.yml` adds the standalone MCAI development services:
PostgreSQL, Redis, Redpanda, router, risk, trade engine, and API. The lightweight
engine containers currently run `payload/neural_ignition.py` and are development
scaffolding, not production trading services.

### Canonical USDT v2

The canonical USDT v2 source directory is `quantumai-usdt-v2/` (without a
leading space). `docker-compose.override.yml` defines its local service and a
Redis dependency.

```bash
docker compose -f docker-compose.base.yml -f docker-compose.override.yml config --quiet
```

The former leading-space directory was a byte-for-byte duplicate and is retired.

### ManagerAI

`compose.managerai.yml` is the dedicated, self-contained ManagerAI control-plane
lane. Use `ops/qai_managerai_stack.sh` for its guarded lifecycle. Apply actions
remain opt-in through `MANAGERAI_APPLY_ON_CRITICAL=1`.

```bash
docker compose -f compose.managerai.yml config --quiet
```

### Runtime and Monitoring

- `backend/qai_runtime/compose.dev.yml` is the FastAPI runtime development lane.
- `compose.monitoring.yml` is the optional monitoring lane.
- `stack/docker-compose.yml` is the isolated legacy stack lane.
- `compose.master.yml` is retained for compatibility and is not the default.

Validate each file independently before use.

## Experimental Overlays

The following files are retained as source/configuration but are not part of the
default merge order:

- `compose.hardening.override.yml`
- `compose.performance.yml`
- `compose.prod.yml`
- `compose.resilience.override.yml`
- `compose.runtime.fix.yml`
- `docker-compose.usdt.yml`

These overlays were authored against older service inventories. Do not combine
them with a supported lane without first checking the rendered service graph,
dependencies, mounts, ports, and health checks.

## Environment Files

- `.env` and `.env.local` are local runtime inputs and must never be committed.
- `.env.example` and explicitly named `*.example` files contain placeholders.
- Prefer `${VARIABLE:-default}` for safe non-secret defaults.
- Production secrets must come from the deployment platform or a secret store.

Both `.env` files are optional for configuration rendering but may be required
to start services that declare `env_file`.

## Network Architecture

- Use Compose service names for container-to-container traffic, never localhost.
- The core gateway services communicate on `mcai_net`.
- Independent lanes get independent project networks unless an explicit shared
  network is documented.
- Host-published control-plane ports should bind to `127.0.0.1` by default.

Examples:

```text
http://gateway:8080
redis://redis:6379/0
```

## Troubleshooting and Validation

Render a lane before every start or deployment:

```bash
docker compose -f FILE config --quiet
```

For a merge, preserve the documented order and render the exact same file list
that will be passed to `up`.

After startup, check both container health and the public HTTP endpoint:

```bash
docker compose -f FILE ps
curl -fsS http://127.0.0.1:PORT/health
```

If a dependency fails, verify that the dependency is present in the rendered
service list, both services share a network, and the health-check command exists
inside the image.
