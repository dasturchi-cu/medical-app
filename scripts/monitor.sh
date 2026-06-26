#!/bin/bash
# =====================================================================
# NEUROSCIENCE APP - VPS HEALTH & LOG MONITORING SCRIPT
# =====================================================================

LOG_FILE="/var/log/neuroscience_monitor.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Running Neuroscience monitor check..." >> "$LOG_FILE"

# 1. Check CPU load
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
echo "[$TIMESTAMP] CPU Load: $CPU_LOAD%" >> "$LOG_FILE"

# 2. Check RAM usage
RAM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
echo "[$TIMESTAMP] Memory Usage: $RAM_USAGE%" >> "$LOG_FILE"

# 3. Check container statuses
DOCKER_DOWN=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}")
if [ -n "$DOCKER_DOWN" ]; then
    echo "[$TIMESTAMP] WARNING: Exited/Dead containers found: $DOCKER_DOWN" >> "$LOG_FILE"
fi

# 4. Probe /health endpoint (Internal request to local Nginx)
HEALTH_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost/health || echo "FAILED")
echo "[$TIMESTAMP] API Health Probe status: $HEALTH_STATUS" >> "$LOG_FILE"

# 5. Hard warnings for thresholds (>70%)
if (( $(echo "$CPU_LOAD > 70.0" | bc -l) )) || (( $(echo "$RAM_USAGE > 70.0" | bc -l) )); then
    echo "[$TIMESTAMP] ALERT: High resource usage detected! CPU: $CPU_LOAD%, RAM: $RAM_USAGE%" >> "$LOG_FILE"
fi

if [ "$HEALTH_STATUS" != "200" ]; then
    echo "[$TIMESTAMP] CRITICAL: API Health Probe failed with status code $HEALTH_STATUS!" >> "$LOG_FILE"
fi
