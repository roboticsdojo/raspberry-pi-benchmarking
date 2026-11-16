#!/usr/bin/env bash
# Shared helpers. Source this file; do not execute it.
#   source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: '$1' not found. Run ./setup.sh (see README) or install it manually." >&2
        exit 1
    }
}

# Returns the SoC temperature as an integer in deg C (0 if unavailable).
soc_temp() {
    if command -v vcgencmd >/dev/null 2>&1; then
        vcgencmd measure_temp | sed -E "s/temp=([0-9]+).*/\1/"
    elif [ -r /sys/class/thermal/thermal_zone0/temp ]; then
        echo $(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
    else
        echo 0
    fi
}

# Returns the throttle bitmask, e.g. 0x0
throttle_flags() {
    command -v vcgencmd >/dev/null 2>&1 && vcgencmd get_throttled | cut -d= -f2 || echo "n/a"
}

# Pre-run sanity check: temperature, throttle flag, CPU topology.
precheck() {
    echo "---- pre-run check ----"
    echo "temp:      $(soc_temp) C (ideally < 50)"
    echo "throttled: $(throttle_flags) (0x0 = clean)"
    lscpu | grep -E "Model name|^CPU\(s\):|Max MHz" || true
    echo "-----------------------"
}

# Wait until the SoC is below a temperature (default 50 C).
wait_for_temp() {
    local target="${1:-50}"
    while [ "$(soc_temp)" -ge "$target" ]; do
        echo "  cooling... $(soc_temp) C (target < ${target} C)"
        sleep 10
    done
}

cooldown() {
    local secs="${1:-${COOLDOWN:-30}}"
    echo "  cool-down ${secs}s..."
    sleep "$secs"
}
