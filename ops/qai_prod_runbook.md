# QAI Production Runbook

## Bootstrap

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_colima_start_and_harden.sh"
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_install_launchagent.sh"
```

## Preflight

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_preflight.sh"
```

## Cutover

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_cutover.sh"
```

## Live Watch

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_watch.sh" 30
```

## Health Summary

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_health_summary.sh"
```

## Rollback

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_rollback.sh"
```
