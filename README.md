# QuantumAI Dockerized System

## Components

* `usdt`: Legacy Flask service (supervisor + nginx in-container) exposing token balance/transfer utilities.
* `quantumai-usdt-v2`: Slim Flask service (Gunicorn, non-root) + Etherscan v2 blueprint (fallback logic + optional caching) served via port 5005 (host).
* `gateway`: Nginx reverse proxy routing `/usdt/*` and `/v2/*` to internal services.
* `redis`: Optional caching backend for Etherscan token holder lookups.
* `dex`: Demo microservice (health + placeholder swap logic).
* `gli`, `gli-mainnet`, `gli-sepolia`: External images (optional) providing additional logic.
* `integrations/etherscan`: Shared Etherscan clients & blueprints.
* `integrations/linear`: Linear.app GraphQL client + Flask blueprint + AI signal issue sync.

### Quick Start (Development)

1. Clone & enter repo.
1. Copy env file: `cp .env.example .env` (REMOVE real keys before committing; use placeholders).
1. Create venv & install:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

1. Run tests:

```bash
pytest -q
```

1. Build stack:

```bash
docker compose build
```

1. Start services:

```bash
docker compose up -d redis
docker compose up -d
```

Local run (v2 only):

```bash
make run-v2
```

1. Hit endpoints:

```bash
curl http://localhost:5003/health
curl http://localhost:5003/usdt/
curl "http://localhost:5003/v2/etherscan/tokenholders?contract=0xdAC17F958D2ee523a2206206994597C13D831ec7&limit=2"
```

### Environment Variables (Core)

```env
INFURA_PROJECT_ID=...        # optional for richer web3
ETHERSCAN_API_KEY=...
ETH_SENDER_ADDRESS=0x...
ETH_PRIVATE_KEY=             # leave empty for dry-run
GLI_DRY_RUN=1                # preview only
REDIS_URL=redis://redis:6379/0  # optional caching
ETHERSCAN_CACHE_TTL=60          # seconds (holders list)
DISABLE_CACHE=0                # set 1 to bypass cache (debug)
LOG_LEVEL=INFO                 # structured log level
```

### Security

* Private keys & API keys currently present in history must be ROTATED immediately.
* Use docker secrets / vault in production; do not store secrets in images or git.
* Enable rate limiting & TLS termination (gateway is plain HTTP by default).

### Makefile Targets

```text
make venv | make install | make dev | make test | make build | make compose-up | make compose-down
```

### Linear.app Integration

Linear entegrasyonu Flask app içine `/linear/*` route'ları olarak kayıt edilir:

```bash
curl http://localhost:5000/linear/health
curl http://localhost:5000/linear/teams
```

AI sinyalini Linear issue olarak göndermek için:

```bash
make linear-signal-issue
```

Read-only bağlantı doğrulaması:

```bash
make linear-smoke
```

Ops zincirine dahil etmek için `LINEAR_AUTO_CREATE_ISSUE=1` ve `LINEAR_API_KEY` tanımlanır; bu durumda [ops/qai_ai_token_chain.sh](/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221%203/ops/qai_ai_token_chain.sh) son AI sinyalinden otomatik Linear issue üretir.

### Production Hints

* Remove host port exposure for internal services (only expose gateway).
* Switch `usdt` service to a simpler gunicorn-only image (drop supervisor) for lean runtime.
* Add CI secrets scanning + Ruff lint enforcement.

### Troubleshooting

* 502 from gateway: check: `docker compose logs gateway usdt quantumai-usdt-v2 gateway`
* Etherscan NOTOK errors: ensure `CHAIN_ID` / `ETHERSCAN_API_KEY` correct; fallback tries `tokens` → `token` modules.
* Import errors in editor: verify selected interpreter is repo `.venv`.

### Container Log Files

Container içinde gerçek log dosyaları şu path'lerde tutulur:

* `gateway`: `/var/log/nginx/access.log` ve `/var/log/nginx/error.log`
* `dex`, `quantumai-usdt`, `quantumai-usdt-v2`, `gli`, `gli-mainnet`, `gli-sepolia`: `/var/log/qai/access.log` ve `/var/log/qai/error.log`

Tek komutla container içi logları görmek için:

```bash
bash ops/qai_inside_logs.sh gateway
bash ops/qai_inside_logs.sh usdt-v2
FOLLOW=1 LINES=100 bash ops/qai_inside_logs.sh all
```

### Next Steps (Optional)

* Consolidate duplicated USDT app variants into a single maintained entrypoint.
* Extend caching (Redis) from holders to balances & transfers with differentiated TTLs.
* Add structured JSON logging (gunicorn `--access-logfile -` with formatter) & log shipping.

### One-Step Migration / Validation

After Docker is available you can perform build, minimal stack startup, health checks, and (optionally) purge the legacy spaced directory in one command:

```bash
./scripts/one_step_migrate_v2.sh            # build + verify only
./scripts/one_step_migrate_v2.sh --purge     # also remove legacy directory
./scripts/one_step_migrate_v2.sh --purge --strict  # plus CI strict vuln guidance
```

Options: `--silent` (less curl output), `TIMEOUT_SECS=60` env to extend wait.

### Multi-Arch Builds

GitHub Actions workflow `build-multiarch.yml` builds `quantumai-usdt-v2` for `linux/amd64` and `linux/arm64`:

Local (no push):

```bash
make buildx-v2
```

One-step script variant:

```bash
./scripts/one_step_migrate_v2.sh --multiarch
```

CI (manual dispatch with push): trigger the workflow and set `push=true` (requires `DOCKERHUB_USERNAME` & `DOCKERHUB_TOKEN` secrets).

### SBOM & Provenance

GitHub workflow `build-multiarch.yml` can optionally:

* Generate SBOM (default `sbom=true` on manual dispatch) using Syft (`anchore/sbom-action`).
* Emit provenance attestations when `provenance=true` (requires modern cosign tooling by GitHub runners; disabled by default).

Manual local SBOM (after building image):

```bash
./scripts/generate_sbom.sh quantumai-usdt-v2:latest
```

Provenance guidance:

1. Dispatch workflow with `provenance=true` & `push=true`.
2. Retrieve attestation via `cosign verify-attestation` (if keyless signing supported on your registry).

Note: Attestations/SBOM are not security guarantees but foundational supply chain metadata—pair with vulnerability + signature verification.
* Integrate vulnerability scanning (Trivy or Docker Scout) in CI.
* Add secret scanning pre-commit (detect-secrets / trufflehog) and rotation script.
