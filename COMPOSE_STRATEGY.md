# Docker Compose Merge Strategy

## Overview
This document specifies how Docker Compose files are merged and prioritized in QuantumAI-Dockerized-System.

## File Hierarchy & Merge Order

When running `docker compose up`, files are merged in this order (last wins):

```bash
docker compose \
  --file compose.yml \                    # 1. Base services (dex, usdt-v2, gateway, gli, etc.)
  --file docker-compose.base.yml \        # 2. MCAI services (api, router, sim, postgres, redis, redpanda)
  --file compose.override.yml \           # 3. Local dev overrides (optional)
  --project-name quantumai-stack \
  up -d
```

## File Descriptions

### 1. `compose.yml` (PRIMARY)
**Purpose**: Main application stack
**Contains**:
- Gateway (Nginx reverse proxy)
- Core services: dex, quantumai-usdt, quantumai-usdt-v2
- GLI (Generalized Liquidity Interface) x3 instances
- RossettaAI (model serving)
- Metrics (Prometheus exporter)
- managerai (AI orchestrator)
- Demo apps (demo-app-qai, demo-app-redis, demo-app-redpanda)
- Redis cache (port 6381)
- Watchtower (container updates)

**Networks**:
- `default`: All main services + gateway
- `demo_core`: Demo apps
- `demo_data`: Demo apps
- `mcai_net`: MCAI services (isolated)
- `monitoring`: Metrics scraping

### 2. `docker-compose.base.yml` (MCAI STACK)
**Purpose**: Market, routing, and simulation microservices
**Contains** (12 services):
- mcai-api, mcai-feeder, mcai-router
- mcai-sim, mcai-large-exec
- mcai-risk, mcai-small-agg
- mcai-trade-engine
- mcai-postgres (PostgreSQL 16, port 55433)
- mcai-redis (Redis 7-alpine, port 6380)
- mcai-redpanda (Kafka broker, port 29093)

**Networks**:
- Uses `default` network (defined as empty `{}`)
- **BUG**: Should use `mcai_net` for network_mode or explicit network assignment
- Currently, MCAI services are on composed network, NOT isolated

### 3. `compose.override.yml` (LOCAL DEV)
**Purpose**: Override settings for local development
**Examples**:
- Increase resource limits for debugging
- Add volume mounts for source code
- Change ports for Colima integration

### Optional Files (Do NOT Merge By Default)
- ❌ `compose.master.yml` - Fallback/legacy (don't use)
- ❌ `compose.monitoring.yml` - Extra monitoring (conditional)
- ❌ `compose.debug.yaml` - Debug mode (conditional)
- ❌ `compose.managerai.yml` - ManagerAI specific (conditional)
- ❌ `compose.hardening.override.yml` - Security hardening (conditional)
- ❌ `compose.runtime.fix.yml` - Bug fixes (conditional, broken)
- ❌ `docker-compose.usdt.yml` - USDT only (deprecated)

---

## Recommended Compose Commands

### Standard Startup (Development)
```bash
docker compose \
  --file compose.yml \
  --file docker-compose.base.yml \
  --file compose.override.yml \
  --project-name quantumai-stack \
  up -d
```

### Production Startup
```bash
docker compose \
  --file compose.yml \
  --file docker-compose.base.yml \
  --file compose.prod.yml \        # (create if needed)
  --project-name quantumai-stack \
  up -d
```

### Monitoring Only
```bash
docker compose \
  --file compose.yml \
  --file compose.monitoring.yml \
  --project-name quantumai-stack \
  up -d
```

---

## Network Architecture

### Current State (Mixed)
```
Main Stack (compose.yml):
┌─────────────────────────────────────┐
│ default network                     │
├─────────────────────────────────────┤
│ gateway → dex, usdt-v2, gli, etc   │
│ managerai → [all above]             │
│                                     │
│ ISSUE: mcai_net defined but         │
│        services use default!        │
└─────────────────────────────────────┘

MCAI Stack (docker-compose.base.yml):
┌─────────────────────────────────────┐
│ default network (from compose)      │
├─────────────────────────────────────┤
│ mcai-api, mcai-router, mcai-sim     │
│ mcai-postgres, mcai-redis           │
│ mcai-redpanda                       │
│                                     │
│ ISSUE: Shares 'default' with main   │
│        stack - unnecessary coupling │
└─────────────────────────────────────┘
```

### Recommended State (Isolated)
```
┌─────────────────────────┐   ┌──────────────────────┐
│ default (main stack)    │   │ mcai_net (MCAI)      │
├─────────────────────────┤   ├──────────────────────┤
│ gateway                 │   │ mcai-api             │
│ dex, usdt-v2, gli       │   │ mcai-router          │
│ rosettaai, managerai    │   │ mcai-sim             │
│ redis, metrics          │   │ mcai-postgres        │
└─────────────────────────┘   │ mcai-redis           │
         ↓                     │ mcai-redpanda        │
    Can access main           └──────────────────────┘
    services via DNS
    (gateway, etc)        (Optional) API Gateway
                          between mcai_net & default
```

---

## Configuration Management

### Environment Variables
- **`.env.local`**: Local development (override .env.example)
- **`.env`**: Runtime environment (git-ignored, never commit)
- **`env.template`**: Template with all available options
- **`.env.example`**: Example with placeholder values

All environment variables use defaults:
```bash
${VARIABLE:-default_value}
```

### How to Start Different Stack Configurations

#### Option 1: Full Stack (Recommended)
```bash
# Both main + MCAI services
docker compose \
  --file compose.yml \
  --file docker-compose.base.yml \
  up -d
```

#### Option 2: Main Stack Only
```bash
# Gateway, API services, no MCAI
docker compose --file compose.yml up -d
```

#### Option 3: MCAI Only
```bash
# Market engines, feeder, etc.
# WARNING: Will fail because depends_on missing
docker compose --file docker-compose.base.yml up -d
```

---

## Dependency Chain

```
Main Stack Order:
  1. redis (no deps) → starts first
  2. dex, usdt, rosettaai (start in parallel)
  3. gateway (depends_on: dex, usdt-v2, rosettaai) → starts when all healthy
  4. managerai (depends_on: SUPERVIZOR_COMPOSE_FILES) → orchestrates rest
  5. metrics (depends_on: gateway, usdt-v2, rosettaai, managerai)

MCAI Stack Order:
  1. mcai-postgres (service_started)
  2. mcai-redis (service_healthy)
  3. mcai-redpanda (service_healthy)
  4. mcai-* services (all above must be healthy)
```

---

## Health Check Strategy

All services follow this pattern:
```yaml
healthcheck:
  test:
    - CMD-SHELL
    - wget -q -O - http://127.0.0.1:PORT/health || curl -fsS http://127.0.0.1:PORT/health
  interval: 20s
  timeout: 10s
  retries: 12
  start_period: 30s
```

**Probes used**:
- HTTP `/health` endpoint (preferred)
- Fallback to `/` if `/health` unavailable
- Redis: `redis-cli ping`
- PostgreSQL: `pg_isready`

---

## Troubleshooting

### Problem: "dependency failed to start"
```
Check compose merge order:
  1. Verify --file order is correct
  2. Check service.depends_on.service_name exists in merged config
  3. Increase retries/timeout in healthcheck
```

### Problem: "service not found" (container-to-container)
```
Check networks:
  1. Both services must be on same network (default or mcai_net)
  2. Use service hostname (not localhost)
  3. Example: http://gateway:8080 NOT http://localhost:8080
```

### Problem: "MCAI services failing"
```
Check docker-compose.base.yml networks:
  1. Should define mcai_net explicitly
  2. OR use external: true to reference compose.yml's mcai_net
  3. Services should NOT share 'default' with main stack
```

---

## Future Improvements

1. **Create `compose.prod.yml`**
   - Remove dev volumes
   - Set resource limits stricter
   - Add logging centralization

2. **Create `compose.ci.yml`**
   - Scale down to minimal services
   - Use test databases
   - Disable autoheal/watchtower

3. **Unify Network Strategy**
   - Keep mcai_net isolated
   - Add API gateway between default & mcai_net if needed
   - Document service-to-service communication rules

4. **Auto-Documentation**
   - Generate from compose files dynamically
   - Include port mappings, env vars per service
   - Output as table/visual diagram

---

## References
- [Docker Compose Docs](https://docs.docker.com/compose/compose-file/)
- [Networking Guide](https://docs.docker.com/compose/networking/)
- [Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)
