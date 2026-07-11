# Living Spring (managerai) Performance Optimization Guide

## 📊 Current Status

✅ **Container Health:** Healthy
✅ **CPU Usage:** 0.16% (Very Low)
✅ **Memory Usage:** 0.50% (39.58 MiB / 7.738 GiB)
✅ **Error Rate:** 0/1117 requests (0%)
✅ **Request Processing:** 1117 requests with 0 failures

---

## 🔍 Performance Analysis

### Current Metrics
- **Uptime:** Container running since 2026-03-19 15:26:18 UTC
- **Process:** Uvicorn (PID 19025)
- **Total Requests Processed:** 1,117
- **Response Status:** All 200 OK (100% success rate)
- **Active Connections:** Minimal
- **Disk I/O:** 246kB read, 0B written

### Key Observations
1. **Low Resource Utilization** - CPU and memory are not bottlenecks
2. **High Request Volume** - Handling 1000+ requests successfully
3. **No Errors** - Zero application errors or crashes
4. **Healthy Dependencies** - PostgreSQL and Redis are accessible

---

## 🚀 Performance Optimization Recommendations

### 1. **Uvicorn Worker Configuration**
**Current:** 1 worker (default)
**Recommended:** 2-4 workers based on CPU cores

Update `compose.yml`:
```yaml
managerai:
  command:
    - uvicorn
    - managerai.app:app
    - --host=0.0.0.0
    - --port=8012
    - --workers=4  # ← ADD THIS
    - --loop=uvloop  # ← Optional: faster event loop
```

### 2. **Resource Limits & Requests**
```yaml
managerai:
  resources:
    limits:
      cpus: "1.0"
      memory: 512M
    reservations:
      cpus: "0.5"
      memory: 256M
```

### 3. **Caching Strategy**
- Enable Redis for session caching
- Add HTTP caching headers
- Implement request memoization

### 4. **Connection Pooling**
```python
# In your FastAPI app
from sqlalchemy.pool import QueuePool

DATABASE_URL = "postgresql://qai:qai@postgres:5432/qaidb"
engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=5,
    max_overflow=20,
    pool_pre_ping=True,
    pool_recycle=3600  # Recycle connections every hour
)
```

### 5. **Async Request Handling**
Ensure all I/O operations are async:
```python
@app.get("/api/data")
async def get_data():
    # Use async/await for all database queries
    result = await db.fetch("SELECT ...")
    return result
```

### 6. **Enable Compression**
```yaml
managerai:
  environment:
    COMPRESSION: "gzip"  # If your FastAPI app supports it
```

### 7. **Health Check Optimization**
The `/healthz` endpoint is being called 980+ times. Optimize it:
```python
# Simple, fast health check
@app.get("/healthz", response_class=PlainTextResponse)
async def healthz():
    return "OK"  # Minimal response
```

### 8. **Monitoring & Logging**
- Set `PYTHONUNBUFFERED=1` ✓ (Already set)
- Reduce verbose logging in production
- Use structured logging (JSON)

---

## 📈 Performance Testing

### Load Testing
```bash
# Using Apache Bench
ab -n 10000 -c 100 http://localhost:8012/healthz

# Using wrk
wrk -t4 -c100 -d30s http://localhost:8012/healthz

# Using hey
hey -n 10000 -c 100 -m GET http://localhost:8012/healthz
```

### Continuous Monitoring
```bash
# Real-time container metrics
docker stats living_spring --no-stream

# Monitor logs with filtering
docker logs -f living_spring | grep -E "error|warning|exception"

# Custom monitoring script
./monitor_living_spring.sh
```

---

## 🔧 Implementation Checklist

- [ ] Review `managerai/app.py` for async/await patterns
- [ ] Update `compose.yml` with worker configuration
- [ ] Add resource limits to prevent memory leaks
- [ ] Verify database connection pooling
- [ ] Test with increased load (wrk/ab)
- [ ] Set up continuous performance monitoring
- [ ] Add performance metrics export (Prometheus)
- [ ] Review application startup time
- [ ] Optimize database queries with explain plans
- [ ] Implement caching layer for frequently accessed data

---

## 🐛 Troubleshooting Commands

```bash
# View detailed diagnostics
docker logs --tail 500 living_spring | grep -iE "error|warning|exception"

# Check process details
docker top living_spring

# Inspect container configuration
docker inspect living_spring | jq '.Config'

# Monitor real-time performance
watch -n 1 'docker stats --no-stream living_spring'

# Check network connectivity
docker exec living_spring curl -s http://postgres:5432 && echo "DB OK"
docker exec living_spring redis-cli -h redis ping && echo "Redis OK"

# View resource cgroup limits
docker exec living_spring cat /sys/fs/cgroup/memory/memory.limit_in_bytes
docker exec living_spring cat /sys/fs/cgroup/memory/memory.usage_in_bytes
```

---

## 📊 Performance Baseline

Create baseline metrics for comparison:
```bash
# Run once and capture
docker stats --no-stream --format "{{json .}}" living_spring > baseline_$(date +%s).json

# Compare over time
for i in {1..5}; do
  docker stats --no-stream --format "{{json .}}" living_spring >> performance_log.jsonl
  sleep 10
done
```

---

## 🎯 Next Steps

1. **Review Application Code**: Check `managerai/app.py` for performance issues
2. **Implement Recommendations**: Update compose.yml with optimizations
3. **Load Testing**: Use wrk or Apache Bench to stress test
4. **Monitor**: Run continuous monitoring for 24 hours
5. **Analyze**: Compare metrics before/after optimization

For detailed performance profiling, use the provided scripts:
- `./monitor_living_spring.sh` - Quick health check
- `./profile_living_spring.sh` - Detailed performance analysis
