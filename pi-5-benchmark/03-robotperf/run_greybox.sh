#!/usr/bin/env bash
# RDI-41 grey-box (LTTng) runs: trace -> play bag -> stop -> analyze, for one preset.
#
# Usage: ./run_greybox.sh <preset> [--pmic]
#
#   a2                  rectify only            1x (30 Hz)
#   a5                  resize only             1x
#   a1-nodes            rectify+resize, separate processes  1x
#   a1-composable       rectify+resize, one container       1x
#   a1-composable-2x    composable, 2x playback (60 Hz)
#   d1-nodes-1x         xarm6 TF tree, separate nodes       1x
#   d1-composable-1x    xarm6, composable                   1x
#   d1-composable-5x    xarm6, composable, 5x playback (150 Hz TF)
#
# --pmic also runs scripts/pmic_bridge.py (power) during the trace.
#
# !! Read the README section "Grey-box prerequisites" first: the manual upstream
# !! fixes (benchmark_utilities patch, launch-file remaps, tracepoint trimming)
# !! are NOT automated here and the runs will fail or give wrong data without them.
#
# Needs the 'tracing' group (re-login after setup.sh).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"
source "$HERE/../common/lib.sh"

PRESET="${1:-}"; PMIC=0; [ "${2:-}" = "--pmic" ] && PMIC=1
ASSETS="$ROS2_BENCHMARK_OVERRIDE_ASSETS_ROOT/datasets"
EXTRA=()

case "$PRESET" in
    a2)               PKG=a2_rectify; NAME=a2_rectify;             BAG=perception/r2b_galileo2;  RATE=1.0 ;;
    a5)               PKG=a5_resize;  NAME=a5_resize;              BAG=perception/r2b_galileo2;  RATE=1.0 ;;
    a1-nodes)         PKG=a1_perception_2nodes; NAME=a1_perception_2nodes; BAG=perception/r2b_galileo2; RATE=1.0; EXTRA=(use_composable_nodes:=False) ;;
    a1-composable)    PKG=a1_perception_2nodes; NAME=a1_perception_2nodes; BAG=perception/r2b_galileo2; RATE=1.0; EXTRA=(use_composable_nodes:=True) ;;
    a1-composable-2x) PKG=a1_perception_2nodes; NAME=a1_perception_2nodes; BAG=perception/r2b_galileo2; RATE=2.0; EXTRA=(use_composable_nodes:=True) ;;
    d1-nodes-1x)      PKG=d1_xarm6_planning_and_traj_execution; NAME=d1_xarm6; BAG=manipulation/r2b_robotarm; RATE=1.0; EXTRA=(use_composable_nodes:=False) ;;
    d1-composable-1x) PKG=d1_xarm6_planning_and_traj_execution; NAME=d1_xarm6; BAG=manipulation/r2b_robotarm; RATE=1.0; EXTRA=(use_composable_nodes:=True) ;;
    d1-composable-5x) PKG=d1_xarm6_planning_and_traj_execution; NAME=d1_xarm6; BAG=manipulation/r2b_robotarm; RATE=5.0; EXTRA=(use_composable_nodes:=True) ;;
    *) sed -n '2,20p' "$0"; exit 1 ;;
esac

BAG_DIR="$ASSETS/$BAG"
[ -f "$BAG_DIR/metadata.yaml" ] || { echo "ERROR: $BAG_DIR missing. Run ./download_datasets.sh"; exit 1; }

TRACE_DIR="$HOME/.ros/tracing/$NAME"
OUT="$ROBOTPERF_RESULTS_DIR/greybox/$PRESET"
mkdir -p "$OUT"
rm -rf "$TRACE_DIR"   # avoid mixing with a previous run's trace

precheck

PMIC_PID=""
if [ "$PMIC" = "1" ]; then
    PMIC_LOG="$OUT/pmic.csv" python3 "$HERE/scripts/pmic_bridge.py" >"$OUT/pmic_bridge.log" 2>&1 &
    PMIC_PID=$!
fi

echo ">>> tracing: ros2 launch $PKG trace_${NAME}.launch.py ${EXTRA[*]}"
setsid ros2 launch "$PKG" "trace_${NAME}.launch.py" "${EXTRA[@]}" >"$OUT/trace_launch.log" 2>&1 &
LAUNCH_PID=$!
sleep 10   # let the pipeline come up before playback

echo ">>> playing $BAG at ${RATE}x"
ros2 bag play "$BAG_DIR" --qos-profile-overrides-path "$HERE/qos_overrides.yaml" -r "$RATE"
sleep 3

echo ">>> stopping trace"
kill -INT "-$LAUNCH_PID" 2>/dev/null || true
for _ in $(seq 1 30); do kill -0 "$LAUNCH_PID" 2>/dev/null || break; sleep 1; done
kill -9 "-$LAUNCH_PID" 2>/dev/null || true
[ -n "$PMIC_PID" ] && kill "$PMIC_PID" 2>/dev/null

echo ">>> analyzing"
ros2 launch "$PKG" "analyze_${NAME}.launch.py" \
    hardware_device_type:=cpu \
    trace_path:="$TRACE_DIR" \
    "metrics:=[latency, throughput]" 2>&1 | tee "$OUT/analysis.txt"

cp -r "$TRACE_DIR" "$OUT/trace" 2>/dev/null || true
echo "Done. $OUT  (record mean latency + throughput from analysis.txt)"
