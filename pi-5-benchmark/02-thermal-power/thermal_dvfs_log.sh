#!/usr/bin/env bash
# Logs temp, ARM clock, core voltage and throttle bitmask every $INTERVAL seconds (default 2).
#
# Why vcgencmd and not /sys/devices/system/cpu/.../scaling_cur_freq:
# clocks, power and thermal limits are owned by the VideoCore firmware. When it
# throttles, the kernel's cpufreq view can still report the requested 2400 MHz
# while `vcgencmd measure_clock arm` shows the real (throttled) clock.
#
# Usage: ./thermal_dvfs_log.sh output.csv

if [ -z "${1:-}" ]; then
    echo "Error: provide an output CSV filename (e.g. ./thermal_dvfs_log.sh active_cooling_test.csv)"
    exit 1
fi

INTERVAL="${INTERVAL:-2}"
echo "Seconds,Temp_C,Clock_MHz,Voltage_V,Throttled_Hex" > "$1"
start_time=$(date +%s)

echo "Logging to $1 every ${INTERVAL}s. Ctrl+C to stop."

while true; do
    elapsed=$(( $(date +%s) - start_time ))
    temp=$(awk '{printf "%.2f", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
    mhz=$(vcgencmd measure_clock arm | awk -F= '{printf "%.2f", $2/1000000}')
    volt=$(vcgencmd measure_volts core | awk -F= '{printf "%.3f", substr($2,1,length($2)-1)}')
    throttle=$(vcgencmd get_throttled | awk -F= '{print $2}')

    echo "$elapsed,$temp,$mhz,$volt,$throttle" >> "$1"
    echo "Time: ${elapsed}s | Temp: ${temp}C | Clock: ${mhz}MHz | V: ${volt}V | Status: ${throttle}"
    sleep "$INTERVAL"
done
