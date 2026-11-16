#!/usr/bin/env bash
# RDI-41 black-box perception tests (a1, a2, a5) + resolution sweep.
#
# Usage: ./run_blackbox.sh [default|sweep|all]     (default: all)
#   default : a1, a2, a5 at RESIZE_SCALE=0.5
#   sweep   : a1 and a5 at RESIZE_SCALE = 1.0, 0.5, 0.25
#
# Prereq: setup.sh and download_datasets.sh perception
# Output: results/<test>.json (ros2_benchmark log) and results/*_power.csv (PMIC)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"
source "$HERE/../common/lib.sh"
need launch_test

OUT="$ROBOTPERF_RESULTS_DIR"
DATASET="$ROS2_BENCHMARK_OVERRIDE_ASSETS_ROOT/datasets/perception/r2b_galileo2/r2b_galileo2_0.mcap"
[ -f "$DATASET" ] || { echo "ERROR: dataset missing. Run ./download_datasets.sh perception"; exit 1; }

run_one() {   # run_one <script> <label> [RESIZE_SCALE]
    local script="$1" label="$2" scale="${3:-0.5}"
    echo; echo ">>> $label (RESIZE_SCALE=$scale)"
    rm -f /tmp/r2b-log-*.json   # so the mv below only ever sees this run's log
    RESIZE_SCALE="$scale" launch_test "$HERE/scripts/$script"
    if ls /tmp/r2b-log-*.json >/dev/null 2>&1; then
        mv /tmp/r2b-log-*.json "$OUT/${label}.json"
    else
        echo "WARNING: no /tmp/r2b-log-*.json produced for $label" >&2
    fi
    cooldown "${COOLDOWN:-15}"
}

default_runs() {
    run_one black_box_a1_perception_2nodes.py a1_perception_2nodes
    run_one black_box_a2_rectify.py           a2_rectify
    run_one black_box_a5_resize.py            a5_resize
}

sweep_runs() {
    for s in 1.0 0.5 0.25; do
        run_one black_box_a1_perception_2nodes.py "a1_scale_${s}" "$s"
        run_one black_box_a5_resize.py            "a5_scale_${s}" "$s"
    done
}

precheck
case "${1:-all}" in
    default) default_runs ;;
    sweep)   sweep_runs ;;
    all)     default_runs; sweep_runs ;;
    *) echo "Usage: $0 [default|sweep|all]"; exit 1 ;;
esac

echo; echo "==== achieved frame rates ===="
grep -H "MEAN_FRAME_RATE" "$OUT"/*.json 2>/dev/null || true
echo "Results in $OUT"
