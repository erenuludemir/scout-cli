#!/bin/bash

# =======================================================================
# QUICK REFERENCE: Living Spring Performance Monitoring & Optimization
# =======================================================================

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════════╗
║     LIVING SPRING (managerai) - PERFORMANCE TOOLKIT REFERENCE         ║
╚═══════════════════════════════════════════════════════════════════════╝

📁 NEW FILES CREATED:
═══════════════════════════════════════════════════════════════════════

1. monitor_living_spring.sh
   └─ Quick health check & diagnostics dashboard
   └─ Shows: CPU, memory, errors, warnings, health status
   └─ Usage: bash monitor_living_spring.sh

2. profile_living_spring.sh
   └─ Advanced performance profiling
   └─ Shows: Response times, memory analysis, network I/O, request patterns
   └─ Usage: bash profile_living_spring.sh

3. compose.performance.yml
   └─ Docker Compose performance overrides
   └─ Includes: Worker scaling, resource limits, environment optimizations
   └─ Usage: docker compose -f compose.yml -f compose.performance.yml up -d

4. PERFORMANCE_OPTIMIZATION.md
   └─ Comprehensive optimization guide
   └─ Contains: Detailed recommendations & troubleshooting commands

═══════════════════════════════════════════════════════════════════════

🚀 QUICK START:
═══════════════════════════════════════════════════════════════════════

# 1. Check current status
bash monitor_living_spring.sh

# 2. Run detailed profiling
bash profile_living_spring.sh

# 3. Apply performance optimizations (requires docker compose 2.0+)
docker compose -f compose.yml -f compose.performance.yml up -d managerai

# 4. Verify optimization applied
docker inspect living_spring | grep -A 20 '"Cmd"'

# 5. Monitor continuous performance
watch -n 2 'bash monitor_living_spring.sh | head -20'

═══════════════════════════════════════════════════════════════════════

📊 KEY MONITORING COMMANDS:
═══════════════════════════════════════════════════════════════════════

# Real-time resource monitoring (30 second interval)
watch -n 30 'docker stats --no-stream living_spring'

# Tail application logs
docker logs -f --tail 50 living_spring

# View only errors/warnings
docker logs -f living_spring 2>&1 | grep -iE "error|warning|exception"

# Container inspection
docker inspect living_spring | jq '.State.Health'

# Process details
docker top living_spring

# Check uptime
docker inspect living_spring --format='{{.State.StartedAt}}'

═══════════════════════════════════════════════════════════════════════

🔥 LOAD TESTING TOOLS:
═══════════════════════════════════════════════════════════════════════

# Install load testing tools
brew install wrk  # macOS
# or apt install wrk  # Linux

# Gentle load test (10K requests, 100 concurrent)
wrk -t4 -c100 -d30s http://localhost:8012/healthz

# Heavy load test (100K requests, 1000 concurrent)
wrk -t8 -c1000 -d60s http://localhost:8012/healthz

# Apache Bench alternative
ab -n 10000 -c 100 http://localhost:8012/healthz

═══════════════════════════════════════════════════════════════════════

🎯 CURRENT PERFORMANCE BASELINE:
═══════════════════════════════════════════════════════════════════════

✅ Container Status:    HEALTHY
✅ CPU Usage:           0.16% (Very Low)
✅ Memory Usage:        0.50% (39.58 MiB)
✅ Error Rate:          0/1117 requests (0% failures)
✅ Response Code:       100% 200 OK
✅ Uptime:              8+ minutes
✅ Requests Processed:  1,117 successful

═══════════════════════════════════════════════════════════════════════

📈 OPTIMIZATION ROADMAP:
═══════════════════════════════════════════════════════════════════════

Phase 1: CONFIGURATION (Immediate)
  ├─ [ ] Apply compose.performance.yml overrides
  ├─ [ ] Enable 2-4 worker processes
  └─ [ ] Increase resource limits to 2 CPU / 1GB memory

Phase 2: APPLICATION (Short-term)
  ├─ [ ] Review managerai/app.py for async optimization
  ├─ [ ] Enable connection pooling (PostgreSQL)
  ├─ [ ] Add caching layer (Redis)
  └─ [ ] Optimize database queries

Phase 3: MONITORING (Ongoing)
  ├─ [ ] Set up Prometheus metrics export
  ├─ [ ] Configure Grafana dashboards
  ├─ [ ] Enable structured JSON logging
  └─ [ ] Implement alerting thresholds

═══════════════════════════════════════════════════════════════════════

🛠️ TROUBLESHOOTING MATRIX:
═══════════════════════════════════════════════════════════════════════

Problem        │ Quick Check              │ Fix Command
───────────────┼──────────────────────────┼─────────────────────────
Crashes        │ docker logs -f           │ docker restart living_spring
Slow Response  │ watch docker stats       │ Apply compose.performance.yml
High Memory    │ docker stats --no-stream │ Reduce workers, add limits
Errors in Logs │ docker logs | grep error │ View error details, debug
No Response    │ docker exec ... curl     │ Check postgres/redis conn

═══════════════════════════════════════════════════════════════════════

🤔 COMMON QUESTIONS:
═══════════════════════════════════════════════════════════════════════

Q: How do I know which optimization helped?
A: Compare baseline metrics before & after using:
   docker stats --format "{{json .}}" living_spring > before.json
   (apply optimizations)
   docker stats --format "{{json .}}" living_spring > after.json

Q: Will these changes break anything?
A: No. All changes are in compose overrides and monitoring scripts.
   Original compose.yml remains unchanged. Easy to rollback.

Q: How do I see if workers are actually running?
A: docker top living_spring  (shows process tree)

Q: Can I apply multiple optimizations?
A: Yes! Stack compose files: -f compose.yml -f compose.performance.yml

═══════════════════════════════════════════════════════════════════════

📞 SUPPORT CHECKLIST:
═══════════════════════════════════════════════════════════════════════

If performance issues persist:
  [ ] Run monitor_living_spring.sh and save output
  [ ] Run profile_living_spring.sh and save output
  [ ] Review PERFORMANCE_OPTIMIZATION.md recommendations
  [ ] Check PostgreSQL/Redis connectivity
  [ ] Review managerai error logs for clues
  [ ] Test with load generator to reproduce
  [ ] Compare metrics before/after optimization
  [ ] Check dependencies health status

═══════════════════════════════════════════════════════════════════════

📝 NEXT STEPS:
═══════════════════════════════════════════════════════════════════════

1. Review PERFORMANCE_OPTIMIZATION.md for detailed guide
2. Run the monitoring scripts to gather metrics
3. Apply compose.performance.yml optimizations
4. Perform load testing to validate improvements
5. Set up continuous monitoring for sustained performance

═══════════════════════════════════════════════════════════════════════

✅ READY TO USE!

All tools are ready in your project directory:
  - /Users/erenuludemir/QuantumAI-Dockerized-System.migrated...

Run your first diagnostic:
  bash monitor_living_spring.sh

═══════════════════════════════════════════════════════════════════════

EOF
