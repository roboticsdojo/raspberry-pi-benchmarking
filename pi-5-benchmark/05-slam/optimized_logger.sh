#!/bin/bash
# Per-process logger for the slam_toolbox node (1 Hz) plus SoC temp/clock/throttle.
# Usage: optimized_logger.sh <SLAM_PID> <output.csv>   (exits when the PID exits)
SLAM_PID="$1"
LOGFILE="$2"
echo "Timestamp,SLAM_CPU_%,SLAM_RAM_MB,Temp_C,Clock_GHz,Throttled_Hex" > "$LOGFILE"
while kill -0 "$SLAM_PID" 2>/dev/null; do
    STATS=$(ps -p "$SLAM_PID" -o %cpu,rss | tail -n 1)
    CPU_PCT=$(echo "$STATS" | awk '{print $1}')
    RAM_MB=$(echo "$STATS" | awk '{printf "%.2f", $2/1024}')
    TEMP=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
    CLOCK_GHZ=$(awk '{printf "%.3f", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)
    TIMESTAMP=$(date '+%H:%M:%S')
    echo "$TIMESTAMP,$CPU_PCT,$RAM_MB,$TEMP,$CLOCK_GHZ,$THROTTLED" >> "$LOGFILE"
    sleep 1
done
