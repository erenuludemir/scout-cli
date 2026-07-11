#!/bin/bash

# ======================================================================
# Performance Monitoring & Debugging Dashboard for living_spring (managerai)
# ======================================================================

set -e

CONTAINER_NAME="living_spring"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${PROJECT_DIR}/_logs/living_spring_monitoring"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Living Spring (managerai) Performance Monitoring Dashboard    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ======================================================================
# 1. REAL-TIME RESOURCE MONITORING
# ======================================================================
echo -e "${YELLOW}[1] REAL-TIME RESOURCE USAGE${NC}"
echo "─────────────────────────────────────────"
docker stats --no-stream "$CONTAINER_NAME" --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}"
echo ""

# ======================================================================
# 2. ERROR & WARNING ANALYSIS
# ======================================================================
echo -e "${YELLOW}[2] ERROR & WARNING ANALYSIS${NC}"
echo "─────────────────────────────────────────"
ERROR_COUNT=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | grep -ic "error\|exception\|traceback" | awk '{print $1}' || echo "0")
WARNING_COUNT=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | grep -ic "warning\|warn" | awk '{print $1}' || echo "0")
CRITICAL_COUNT=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | grep -ic "critical\|fatal\|crash" | awk '{print $1}' || echo "0")

echo -e "Total Errors:    ${RED}${ERROR_COUNT}${NC}"
echo -e "Total Warnings:  ${YELLOW}${WARNING_COUNT}${NC}"
echo -e "Critical Issues: ${RED}${CRITICAL_COUNT}${NC}"
echo ""

# Show recent errors if any
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}Recent Errors/Exceptions:${NC}"
    docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | grep -iE "error|exception|traceback" | tail -5
    echo ""
fi

# ======================================================================
# 3. RESPONSE TIME & THROUGHPUT ANALYSIS
# ======================================================================
echo -e "${YELLOW}[3] API PERFORMANCE METRICS${NC}"
echo "─────────────────────────────────────────"

# Count requests by type
HEALTH_CHECKS=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | grep -c "GET /healthz" | awk '{print $1}' || echo "0")
OTHER_REQUESTS=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | grep -c "GET\|POST\|PUT\|DELETE" | awk '{print $1}' || echo "0")
OTHER_REQUESTS=$((OTHER_REQUESTS - HEALTH_CHECKS))

echo "Health Checks:       $HEALTH_CHECKS"
echo "Other Requests:      $OTHER_REQUESTS"
echo "Total Requests:      $((HEALTH_CHECKS + OTHER_REQUESTS))"

# Calculate request rate if logs exist
OLDEST_LOG=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | head -1 | grep -o '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]' | head -1 || echo "")
NEWEST_LOG=$(docker logs "$CONTAINER_NAME" --tail 1000 2>&1 | tail -1 | grep -o '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]' | head -1 || echo "")
echo "Log Time Range:      $OLDEST_LOG to $NEWEST_LOG"
echo ""

# ======================================================================
# 4. HEALTH CHECK STATUS
# ======================================================================
echo -e "${YELLOW}[4] HEALTH & DEPENDENCIES${NC}"
echo "─────────────────────────────────────────"
docker inspect "$CONTAINER_NAME" --format='Health Status: {{.State.Health.Status}}'

# Check dependencies
POSTGRES_HEALTH=$(docker inspect managerai --format='{{.State.Running}}' 2>/dev/null && echo "Running" || echo "Down")
REDIS_HEALTH=$(docker ps --filter "name=redis" --format="{{.Status}}" 2>/dev/null || echo "Not found")

echo "PostgreSQL:          $POSTGRES_HEALTH"
echo "Redis:               $REDIS_HEALTH"
echo ""

# ======================================================================
# 5. PROCESS DETAILS
# ======================================================================
echo -e "${YELLOW}[5] PROCESS DETAILS${NC}"
echo "─────────────────────────────────────────"
docker top "$CONTAINER_NAME" 2>/dev/null || echo "Could not retrieve process details"
echo ""

# ======================================================================
# 6. RECENT LOGS (Last 20 lines)
# ======================================================================
echo -e "${YELLOW}[6] RECENT LOGS (Last 20 Lines)${NC}"
echo "─────────────────────────────────────────"
docker logs --tail 20 "$CONTAINER_NAME" 2>&1 | tail -20
echo ""

# ======================================================================
# 7. SAVE DETAILED LOGS TO FILE
# ======================================================================
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="${LOG_DIR}/living_spring_diagnostic_${TIMESTAMP}.log"

{
    echo "Living Spring (managerai) Diagnostic Report"
    echo "Timestamp: $(date)"
    echo "=================================================="
    echo ""
    echo "=== FULL LOGS (Last 500 lines) ==="
    docker logs --tail 500 "$CONTAINER_NAME" 2>&1
    echo ""
    echo "=== FULL CONTAINER INSPECTION ==="
    docker inspect "$CONTAINER_NAME" 2>&1
    echo ""
    echo "=== NETWORK INSPECTION ==="
    docker inspect "$CONTAINER_NAME" --format='Network Settings: {{json .NetworkSettings}}' 2>&1
} > "$LOG_FILE"

echo -e "${GREEN}✓ Detailed diagnostics saved to: $LOG_FILE${NC}"
echo ""

# ======================================================================
# 8. RECOMMENDATIONS
# ======================================================================
echo -e "${YELLOW}[7] TROUBLESHOOTING RECOMMENDATIONS${NC}"
echo "─────────────────────────────────────────"

if [ "${ERROR_COUNT:-0}" -gt 10 ] 2>/dev/null; then
    echo -e "${RED}⚠ HIGH ERROR RATE DETECTED${NC}"
    echo "  → Review errors using: docker logs --tail 500 $CONTAINER_NAME | grep -i error"
    echo "  → Check dependencies: postgres, redis connectivity"
fi

if [ "${CRITICAL_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}⚠ CRITICAL ISSUES FOUND${NC}"
    echo "  → Container may be crashing: docker restart $CONTAINER_NAME"
    echo "  → Check logs: docker logs $CONTAINER_NAME"
fi

echo ""
echo -e "${GREEN}Monitor real-time with: docker logs -f --tail 50 $CONTAINER_NAME${NC}"
echo -e "${GREEN}Continuous monitoring: watch -n 2 'docker stats --no-stream $CONTAINER_NAME'${NC}"
echo ""
