# QuantumAI Docker Ops

## 1) Colima Redis sysctl kalıcılaştır

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_colima_sysctl.sh"
```

## 2) Tüm stack'leri ayağa kaldır

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_stack_ops.sh" up all
```

## 3) Durum kontrolü

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_stack_ops.sh" ps all
```

## 4) HTTP health özeti

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_health_summary.sh"
```

## 5) Stack bazlı log

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_stack_ops.sh" logs master
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_stack_ops.sh" logs main
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_stack_ops.sh" logs base
```

## 6) Güvenli kapatma

```bash
bash "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/qai_stack_ops.sh" down all
```
