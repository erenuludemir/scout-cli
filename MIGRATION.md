# Migration: Consolidating quantumai-usdt-v2 Directory

The repository formerly contained a misnamed service directory with a leading space: `" quantumai-usdt-v2"`.

This caused:

* Fragile build contexts in compose (`context: ./ quantumai-usdt-v2`).
* Coverage path anomalies.
* Duplicate service code (supervisor+nginx vs new gunicorn slim build).

Current canonical service directory: `quantumai-usdt-v2/` (non-root, gunicorn entrypoint).

Legacy artifacts slated for removal:

* `" quantumai-usdt-v2"` (entire directory) after confirming no unique configs required.
* Supervisor-specific files now replaced by direct Gunicorn run.

Validation checklist before deleting legacy dir:

1. `docker compose build quantumai-usdt-v2` succeeds using new Dockerfile.
2. Gateway proxy to `/v2/` returns HTTP 200 from new container.
3. No CI references to the spaced path remain (grep confirms none).
4. Tests pass (`pytest -q`).

Deletion command (once validated):

```bash
git rm -r " quantumai-usdt-v2"
```

Rollback: Restore from prior commit hash if unexpected runtime issues appear.

Post-removal: Re-run coverage to ensure source mapping excludes removed path.

## Post-Removal Hardening (Optional)

* Set `VULN_STRICT=true` in CI (`.github/workflows/ci.yml` env or repository settings) to fail pipeline on HIGH/CRITICAL findings.
* Add runtime health smoke test in CI invoking `docker compose run --rm quantumai-usdt-v2 curl -fsS http://localhost:5002/health`.
* Consider multi-arch build (linux/amd64, linux/arm64) via Buildx.

## Makefile Shortcuts Added

* `make build-v2` – build only the new service image.
* `make up-core` – start minimal stack (redis + v2 + gateway).
* `make health-v2` – quick health probe.
* `make purge-legacy-v2` – removes legacy directory (ensure build validated first).

## NOTE

The actual deletion (`purge-legacy-v2`) should only be executed after a successful local Docker build & runtime verification to avoid accidental loss of un-migrated configuration nuances (e.g., nginx or supervisor tunables). At present Docker daemon was previously unreachable; run `docker info` then proceed.

## External Volume Migration (LaCie Container-QuantumAI)

Target layout (external disk):

- /Volumes/LaCie/Container-QuantumAI (root enclave)
- /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System (primary APP_ROOT)
- /Volumes/LaCie/Container-QuantumAI/Recovered_Backup_28082025/trained_model.json (model data)
- /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System-Log (operational & migration logs)
- /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System-Beckup (timestamped snapshots)

Script: `scripts/migrate_to_external.sh`

Dry run:

```
MODE=dry ./scripts/migrate_to_external.sh
```

Commit (executes rsync + snapshot + APP_ROOT marker):

```
MODE=commit ./scripts/migrate_to_external.sh
export APP_ROOT=/Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System
```

Key guarantees:

- Hash verification between source and destination logged under Log root.
- Timestamped tar snapshot for rollback before any destructive step.
- Model file presence check (warn if missing).
- Idempotent: re-running commit updates changed files, leaves snapshot history.

Post-migration steps:

1. `cd $APP_ROOT && pytest -q` (verify tests)  
2. `docker compose build` (ensure images build on external volume)  
3. Update CI secrets/env to include `APP_ROOT` if scripts rely on it.  
4. Only after validation: (optional) archive or remove original source tree (manual approval required).  

Rollback:

```
mkdir -p restore && tar -xpf /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System-Beckup/<TS>/repo_snapshot.tar -C restore
```

Security & Performance:

- Running directly from external disk isolates workload; consider mounting with `noexec` for data dirs (not code) if supported.
- Future optimization: move large dependency caches (pip, node) into a dedicated cache dir and symlink.
