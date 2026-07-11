# QuantumAI Runtime API

Phase-4 runtime iskeleti.

## Sağlanan uçlar
- `GET /health`
- `GET /ready`
- `GET /metrics`
- `POST /api/orders`
- `POST /v1/commands`
- `GET /v1/commands`
- `GET /admin/outbox`
- `GET /admin/outbox/events`
- `POST /admin/outbox/drain`
- `POST /admin/outbox/replay/{event_id}`
- `POST /admin/outbox/replay-dead-letters`

## Phase-4 eklemeleri
- SQLite tarafında transactional `orders + outbox_events` yazımı
- Ayrı `api` ve `worker` servisleri
- Postgres / Redis / Kafka yayınının API isteğinden ayrıştırılması
- Prometheus uyumlu `/metrics` yüzeyi
- Provisioned Grafana dashboard
- Dead-letter ve replay operatör uçları
- Outbox yaşlanması ve relay deneme toplamları için ek metrikler
- Docker Compose ile tam lokal servis omurgası
- Tekrar deneme ve replay için outbox durum takibi

## Lokal stack başlatma

```bash
backend/qai_runtime/boot_local_stack.sh
```

## Not

SQLite yerel dayanıklılık ve outbox katmanı olarak kalır.
API siparişi kabul ettiğinde önce `orders` ve `outbox_events` tablolarını atomik olarak yazar.
Relay katmanı daha sonra:
- Postgres order mirror
- Redis idempotency izi
- Kafka/Redpanda `orders.incoming` yayını

Phase-4 ile varsayılan geliştirme topolojisi:
- `qai-runtime-api`
- `qai-runtime-worker`
- `qai-postgres`
- `qai-redis`
- `qai-redpanda`
- `qai-prometheus`
- `qai-grafana`

Manuel local süreç modu hâlâ kullanılabilir:

```bash
cd backend/qai_runtime
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8787

export QAI_ENABLE_EMBEDDED_RELAY=0
python -m app.worker
```

Lokal gelistirme icin:

```bash
colima start
docker compose -f backend/qai_runtime/compose.dev.yml up -d --build
```

Tam lokal stack:

```bash
backend/qai_runtime/boot_local_stack.sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/metrics
open http://127.0.0.1:9090
open http://127.0.0.1:3000
```

Test:

```bash
cd backend/qai_runtime
.venv313/bin/python -m unittest discover -s tests
```
