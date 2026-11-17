#!/bin/bash
# run_benchmark.sh
#
# Runs all 8 slam_toolbox benchmark configurations back-to-back, unattended.
# Edit the matrix in config.sh. Outputs land in work/ (trajectories, maps, slam logs)
# and work/logs/ (per-run resource CSVs).
#
# Prereq: ./setup.sh and ./prepare_dataset.sh
# Tip: run inside tmux so an SSH drop does not kill it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source /opt/ros/jazzy/setup.bash

mkdir -p "$LOG_DIR"
cd "$BENCH_DIR" || { echo "ERROR: $BENCH_DIR not found - run ./prepare_dataset.sh first"; exit 1; }
[ -d "$BAG_IN" ] || { echo "ERROR: $BAG_IN missing - run ./prepare_dataset.sh first"; exit 1; }

# Clear out anything left running from a previous aborted attempt before starting
pkill -9 -f slam_toolbox_launch.py 2>/dev/null || true
pkill -9 -f async_slam_toolbox_node 2>/dev/null || true
pkill -9 -f "ros2 bag record" 2>/dev/null || true
pkill -9 -f "rosbag2" 2>/dev/null || true
pkill -9 -f map_saver_cli 2>/dev/null || true
sleep 1

wait_or_kill_group() {
    local pid=$1 timeout=$2 waited=0
    while kill -0 "$pid" 2>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -ge "$timeout" ]; then
            echo "WARNING: process group $pid did not exit within ${timeout}s - force-killing group" >&2
            kill -9 "-$pid" 2>/dev/null || true
            break
        fi
    done
    wait "$pid" 2>/dev/null || true
}

cleanup_stale_processes() {
    pkill -INT -f async_slam_toolbox_node 2>/dev/null || true
    pkill -INT -f "rosbag2" 2>/dev/null || true
    pkill -INT -f "ros2 bag record" 2>/dev/null || true
    sleep 2
    pkill -9 -f async_slam_toolbox_node 2>/dev/null || true
    pkill -9 -f "rosbag2" 2>/dev/null || true
    pkill -9 -f "ros2 bag record" 2>/dev/null || true

    local waited=0
    while ros2 node list 2>/dev/null | grep -q "^/slam_toolbox$"; do
        sleep 0.5
        waited=$((waited + 1))
        if [ "$waited" -ge 10 ]; then
            echo "WARNING: /slam_toolbox still listed after cleanup - continuing anyway" >&2
            break
        fi
    done
}

wait_for_node() {
    local waited=0
    while ! ros2 node list 2>/dev/null | grep -q "^/slam_toolbox$"; do
        sleep 0.5
        waited=$((waited + 1))
        if [ "$waited" -ge $((NODE_WAIT_TIMEOUT * 2)) ]; then
            echo "ERROR: /slam_toolbox did not appear within ${NODE_WAIT_TIMEOUT}s" >&2
            return 1
        fi
    done
    return 0
}

thermal_check() {
    local temp throttled raw
    temp=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    raw=$(vcgencmd get_throttled 2>/dev/null)
    if [[ "$raw" =~ throttled=(0x[0-9a-fA-F]+) ]]; then
        throttled="${BASH_REMATCH[1]}"
    else
        throttled=""
    fi
    echo "  pre-run temp: ${temp:-N/A}C | throttled flag: ${throttled:-unavailable}"
    if [ -n "$throttled" ] && [ "$throttled" != "0x0" ]; then
        echo "  WARNING: non-zero throttled flag - this run's numbers may be confounded by thermal/under-voltage throttling."
    fi
}

run_one() {
    local RUN=$1 RES=$2 RANGE=$3 TPP=$4 RATE=$5
    echo "=== Run $RUN (res=$RES range=$RANGE tpp=$TPP rate=${RATE}x) ==="

    thermal_check
    cleanup_stale_processes
    rm -rf "run${RUN}_traj" "run${RUN}.tum" "map_run${RUN}."* tf_map.base_link.tum pose.tum 2>/dev/null

    # 1. Launch slam toolbox in background (own process group)
    setsid ros2 launch "$LAUNCH_FILE" res:="$RES" range:="$RANGE" tpp:="$TPP" > "run${RUN}_slam_log.txt" 2>&1 &
    local LAUNCH_PID=$!
    if ! wait_for_node; then
        kill -9 "-$LAUNCH_PID" 2>/dev/null || true
        return 1
    fi

    # 2. Resource logging against the real node PID
    local SLAM_PID
    SLAM_PID=$(pgrep -f async_slam_toolbox_node | head -1)
    if [ -z "$SLAM_PID" ]; then
        echo "ERROR: could not find async_slam_toolbox_node PID for run $RUN" >&2
        kill -9 "-$LAUNCH_PID" 2>/dev/null || true
        return 1
    fi
    setsid "$LOGGER_SCRIPT" "$SLAM_PID" "$LOG_DIR/run${RUN}_resource.csv" &
    local LOGGER_PID=$!

    # 3. Bring the lifecycle node up
    ros2 lifecycle set /slam_toolbox configure
    ros2 lifecycle set /slam_toolbox activate

    # 4. Start trajectory recording (background)
    ros2 bag record /tf /pose -o "run${RUN}_traj" > /dev/null 2>&1 &
    local RECORD_PID=$!
    sleep 2

    # 5. Play dataset (blocks until finished)
    ros2 bag play "$BAG_IN" --clock --qos-profile-overrides-path "$QOS_FILE" --rate "$RATE"
    sleep 2

    # 6. Stop recording gracefully with SIGTERM
    kill -TERM "$RECORD_PID" 2>/dev/null || true

    # Wait up to 60 s for buffers to flush to disk cleanly
    local waited=0
    while kill -0 "$RECORD_PID" 2>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -ge 60 ]; then
            echo "WARNING: recorder timed out writing to SD card, force killing" >&2
            kill -9 "$RECORD_PID" 2>/dev/null || true
            break
        fi
    done
    wait "$RECORD_PID" 2>/dev/null || true

    # 7. Save map via service call
    if timeout 20 ros2 service call /slam_toolbox/save_map slam_toolbox/srv/SaveMap "{name: {data: 'map_run${RUN}'}}"; then
        echo "Map saved successfully."
    else
        echo "WARNING: save_map service call failed/timed out for run $RUN - map may be missing" >&2
    fi

    # 8. Shut down node and logger
    kill -INT "-$LAUNCH_PID" 2>/dev/null || true
    wait_or_kill_group "$LAUNCH_PID" 45
    wait_or_kill_group "$LOGGER_PID" 5
    cleanup_stale_processes

    # 9. Extract trajectory as TUM: prefer /tf:map.base_link, fall back to /pose
    evo_traj bag2 "run${RUN}_traj" /tf:map.base_link --save_as_tum >/dev/null 2>&1
    if [ -s tf_map.base_link.tum ]; then
        mv tf_map.base_link.tum "run${RUN}.tum"
    else
        evo_traj bag2 "run${RUN}_traj" /pose --save_as_tum >/dev/null 2>&1
        if [ -s pose.tum ]; then
            mv pose.tum "run${RUN}.tum"
        else
            echo "WARNING: no trajectory extracted for run $RUN" >&2
        fi
    fi
    rm -f tf_map.base_link.tum pose.tum

    echo "=== Run $RUN complete ==="
    sleep "$COOLDOWN_SEC"
}

for entry in "${RUNS[@]}"; do
    IFS=':' read -r RUN RES RANGE TPP RATE <<< "$entry"
    run_one "$RUN" "$RES" "$RANGE" "$TPP" "$RATE"
done

echo
echo "All 8 runs complete."
echo
echo "Trajectories:      $BENCH_DIR/run*.tum"
echo "Maps:              $BENCH_DIR/map_run*.pgm"
echo "SLAM logs:         $BENCH_DIR/run*_slam_log.txt"
echo "Resource logs:     $LOG_DIR/run*_resource.csv"
echo "Next: ./extract_data.sh"
