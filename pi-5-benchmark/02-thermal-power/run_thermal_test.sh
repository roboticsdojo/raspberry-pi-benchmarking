#!/usr/bin/env bash
# RDI-39 [Pi5] Thermal throttling & power draw
#
# Usage: ./run_thermal_test.sh <active|passive> [duration]     (duration default: 20m)
#
#   active  : run with the active cooler fan connected
#   passive : run with the fan cable disconnected (you are prompted to confirm)
#
# Runs stress-ng matrixprod on all 4 cores while thermal_dvfs_log.sh records
# temp / clock / voltage / throttle flags. Output:
#   results/<mode>_cooling_test.csv
#   results/stress_ng_<mode>.txt
#
# Pre-conditions (checked here): SoC < 50 C and throttle flag 0x0. The flag is
# sticky until reboot, so if a previous run throttled, reboot first (or FORCE=1).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/lib.sh"
need stress-ng
need vcgencmd

MODE="${1:-}"
DURATION="${2:-20m}"
case "$MODE" in active|passive) ;; *) echo "Usage: $0 <active|passive> [duration]"; exit 1 ;; esac

OUT="${RESULTS_DIR:-$SCRIPT_DIR/results}"
mkdir -p "$OUT"
CSV="$OUT/${MODE}_cooling_test.csv"

if [ "$MODE" = "passive" ]; then
    read -r -p "Is the active cooler fan cable DISCONNECTED? [y/N] " ans
    [ "$ans" = "y" ] || { echo "Aborted."; exit 1; }
fi

precheck
echo "Waiting for SoC < 50 C..."
wait_for_temp 50

if [ "$(throttle_flags)" != "0x0" ] && [ "${FORCE:-0}" != "1" ]; then
    echo "ERROR: throttle flags are $(throttle_flags), not 0x0. Reboot for a clean start (or FORCE=1)."
    exit 1
fi

"$SCRIPT_DIR/thermal_dvfs_log.sh" "$CSV" >/dev/null &
LOG_PID=$!
trap 'kill $LOG_PID 2>/dev/null' EXIT INT TERM

echo "Running stress-ng (cpu x4, matrixprod) for $DURATION - mode=$MODE"
stress-ng --cpu 4 --cpu-method matrixprod --timeout "$DURATION" --metrics-brief 2>&1 \
    | tee "$OUT/stress_ng_${MODE}.txt"

kill $LOG_PID 2>/dev/null
trap - EXIT INT TERM
echo "Done. $CSV"
echo "Final: temp=$(soc_temp)C throttled=$(throttle_flags)"
