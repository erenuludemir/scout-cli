#!/bin/bash

# ======================================================================
# Advanced Performance Profiling for living_spring
# ======================================================================

CONTAINER_NAME="living_spring"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${PROJECT_DIR}/_logs/living_spring_monitoring"
mkdir -p "$LOG_DIR"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        Advanced Performance Profiling for living_spring         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ======================================================================
# 1. RESPONSE TIME ANALYSIS
# ======================================================================
echo "[1] RESPONSE TIME ANALYSIS"
echo "─────────────────────────────────────────"

# Extract response times from logs (macOS compatible - no Perl regex)
RESPONSE_TIMES=$(docker logs "$CONTAINER_NAME" --tail 500 2>&1 | grep -oE '[0-9]{3}' | sort | uniq -c | sort -rn | head -10)

echo "HTTP Status Code Distribution:"
echo "$RESPONSE_TIMES" | awk '{printf "  Status %s: %s requests\n", $2, $1}'
echo ""

# ======================================================================
# 2. MEMORY & SWAP ANALYSIS
# ======================================================================
echo "[2] MEMORY & SWAP ANALYSIS"
echo "─────────────────────────────────────────"

CONTAINER_ID=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.ID}}" | head -1)
if [ -n "$CONTAINER_ID" ]; then
    # Get memory stats from cgroup
    MEMORY_USAGE=$(docker exec "$CONTAINER_NAME" cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo "N/A")
    MEMORY_LIMIT=$(docker exec "$CONTAINER_NAME" cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "N/A")

    if [ "$MEMORY_USAGE" != "N/A" ] && [ "$MEMORY_LIMIT" != "N/A" ]; then
        MEMORY_USAGE_MB=$((MEMORY_USAGE / 1024 / 1024))
        MEMORY_LIMIT_MB=$((MEMORY_LIMIT / 1024 / 1024))
        MEMORY_PERCENT=$((MEMORY_USAGE * 100 / MEMORY_LIMIT))
        echo "Memory Usage:    $MEMORY_USAGE_MB MB / $MEMORY_LIMIT_MB MB ($MEMORY_PERCENT%)"
    fi
fi

echo ""

# ======================================================================
# 3. NETWORK I/O ANALYSIS
# ======================================================================
echo "[3] NETWORK I/O ANALYSIS"
echo "─────────────────────────────────────────"

TRANSPORT=$(docker exec "$CONTAINER_NAME" netstat -tan 2>/dev/null | grep ESTABLISHED | wc -l || echo "N/A")
echo "Active Connections: $TRANSPORT"

# Check if requests are being queued
LISTEN=$(docker exec "$CONTAINER_NAME" netstat -tan 2>/dev/null | grep LISTEN | wc -l || echo "N/A")
echo "Listening Sockets:  $LISTEN"

echo ""

# ======================================================================
# 4. DISK I/O ANALYSIS
# ======================================================================
echo "[4] DISK I/O ANALYSIS"
echo "─────────────────────────────────────────"

docker stats --no-stream "$CONTAINER_NAME" --format "{{.BlockIO}}"
echo ""

# ======================================================================
# 5. DETAILED REQUEST LOG ANALYSIS
# ======================================================================
echo "[5] REQUEST PATTERNS (Last 100 Requests)"
echo "─────────────────────────────────────────"

docker logs "$CONTAINER_NAME" --tail 500 2>&1 | grep -E "GET|POST|PUT|DELETE|PATCH" | tail -100 | awk -F' ' '{print $NF}' | sort | uniq -c | sort -rn

echo ""

# ======================================================================
# 6. STARTUP TIME & INITIALIZATION PERFORMANCE
# ======================================================================
echo "[6] CONTAINER LIFECYCLE"
echo "─────────────────────────────────────────"

docker inspect "$CONTAINER_NAME" --format='Started:  {{.State.StartedAt}}
Uptime:    {{.State.Pid}} (PID)
HealthCheck: {{.State.Health.Status}}'

echo ""

# ======================================================================
# 7. PYTHON PROCESS ANALYSIS
# ======================================================================
echo "[7] UVICORN PROCESS DETAILS"
echo "─────────────────────────────────────────"

docker exec "$CONTAINER_NAME" ps aux | grep uvicorn || echo "Could not retrieve process details"

echo ""

# ======================================================================
# 8. DEPENDENCY LATENCY CHECK
# ======================================================================
echo "[8] DEPENDENCY CONNECTIVITY TEST"
echo "─────────────────────────────────────────"

# Test connections to dependencies
echo "Testing PostgreSQL connectivity..."
docker exec "$CONTAINER_NAME" python3 -c "
try:
    import psycopg2
    from psycopg2 import connect
    import time
    start = time.time()
    conn = connect('postgresql://qai:qai@postgres:5432/qaidb', connect_timeout=2)
    elapsed = (time.time() - start) * 1000
    print(f'✓ PostgreSQL: {elapsed:.2f}ms')
    conn.close()
except Exception as e:
    print(f'✗ PostgreSQL error: {e}')
" 2>/dev/null || echo "Could not test PostgreSQL"

echo "Testing Redis connectivity..."
docker exec "$CONTAINER_NAME" python3 -c "
try:
    import redis
    import time
    start = time.time()
    r = redis.Redis(host='redis', port=6379, socket_connect_timeout=2)
    r.ping()
    elapsed = (time.time() - start) * 1000
    print(f'✓ Redis: {elapsed:.2f}ms')
except Exception as e:
    print(f'✗ Redis error: {e}')
" 2>/dev/null || echo "Could not test Redis"

echo ""

# ======================================================================
# 9. LOG SUMMARY
# ======================================================================
echo "[9] SUMMARY REPORT"
echo "─────────────────────────────────────────"

TOTAL_LOGS=$(docker logs "$CONTAINER_NAME" --tail 5000 2>&1 | wc -l | awk '{print $1}')
ERRORS=$(docker logs "$CONTAINER_NAME" --tail 5000 2>&1 | grep -ic "error\|exception" | awk '{print $1}' || echo "0")
WARNINGS=$(docker logs "$CONTAINER_NAME" --tail 5000 2>&1 | grep -ic "warning" | awk '{print $1}' || echo "0")
REQUESTS=$(docker logs "$CONTAINER_NAME" --tail 5000 2>&1 | grep -c "GET\|POST\|PUT\|DELETE" | awk '{print $1}' || echo "0")

echo "Total Log Lines:    $TOTAL_LOGS"
echo "Requests Processed: $REQUESTS"
echo "Errors Found:       $ERRORS"
echo "Warnings Found:     $WARNINGS"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "All diagnostics saved to: $LOG_DIR"
echo "════════════════════════════════════════════════════════════════"
