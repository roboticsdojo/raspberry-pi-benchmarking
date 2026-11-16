#!/usr/bin/env bash
# General-purpose system logger: CPU %, RAM %, temp, clock, throttle flags, load.
# Writes one CSV row per second.
#
# Usage (run in background around any benchmark):
#   ./common/system_logger.sh &  LOGGER_PID=$!
#   <your benchmark>
#   kill $LOGGER_PID
#
# Output dir: $LOG_DIR (default: <repo>/logs)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGDIR="${LOG_DIR:-$REPO_ROOT/logs}"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/benchmark_$(date +%Y%m%d_%H%M%S).csv"

echo "Timestamp,CPU_Usage_Pct,RAM_Usage_Pct,Temp_C,Clock_GHz,Throttled_Hex,Load_1m" > "$LOGFILE"
echo "Logging to $LOGFILE (Ctrl+C or kill to stop)"

while true; do
    # CPU usage from two /proc/stat snapshots 0.5 s apart
    CPU_STATS=$(grep 'cpu ' /proc/stat)
    IDLE1=$(echo $CPU_STATS | awk '{print $5}')
    TOTAL1=$(echo $CPU_STATS | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    sleep 0.5
    CPU_STATS=$(grep 'cpu ' /proc/stat)
    IDLE2=$(echo $CPU_STATS | awk '{print $5}')
    TOTAL2=$(echo $CPU_STATS | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    CPU_USAGE=$(awk "BEGIN {print 100*(1-($IDLE2-$IDLE1)/($TOTAL2-$TOTAL1))}")

    RAM_USAGE=$(free | grep Mem | awk '{printf "%.2f", ($3/$2)*100}')

    TEMP=$(vcgencmd measure_temp | tr -d "temp='C")
    CLOCK_RAW=$(vcgencmd measure_clock arm | cut -d= -f2)
    CLOCK_GHZ=$(awk "BEGIN {printf \"%.3f\", $CLOCK_RAW/1000000000}")
    THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)
    LOAD=$(cut -d' ' -f1 /proc/loadavg)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    echo "$TIMESTAMP,$CPU_USAGE,$RAM_USAGE,$TEMP,$CLOCK_GHZ,$THROTTLED,$LOAD" >> "$LOGFILE"
    sleep 0.5
done
