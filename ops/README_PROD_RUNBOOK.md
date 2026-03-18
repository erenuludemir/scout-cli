# QuantumAI Production Runbook

## 1) Colima başlat ve host sertleştir

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_colima_start_and_harden.sh"
```

## 2) LaunchAgent kur

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_install_launchagent.sh"
```

## 3) Preflight

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_preflight.sh"
```

## 4) Cutover

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_cutover.sh"
```

## 5) Sürekli izleme

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_watch.sh" 30
```

## 6) Manuel sağlık özeti

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_health_summary.sh"
```

## 7) Rollback

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_prod_rollback.sh"
```
