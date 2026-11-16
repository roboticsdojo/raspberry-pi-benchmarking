#!/usr/bin/env bash
# RDI-43 middleware matrix: 3 RMWs x 5 topologies x IPC {off,on}, 60 s each.
#   RMWs:       Fast DDS, Cyclone DDS, Zenoh
#   Topologies: baseline, frequency_stress, size_stress, scale_stress, fan_in_stress
#
# Usage: ./run_matrix.sh        (about 3 * 5 * 2 * ~70 s = ~35 min plus cool-downs)
# Env:   TEST_DURATION (default 60), IMAGE_NAME
#
# Before each run it checks the SoC: if >= 75 C or throttled it waits until < 60 C and clean.
# Results: results/<rmw>/<topology>/ipc_<on|off>/

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RMW_LIST=("rmw_fastrtps_cpp" "rmw_cyclonedds_cpp" "rmw_zenoh_cpp")
JSON_FILES=("baseline.json" "frequency_stress.json" "size_stress.json" "scale_stress.json" "fan_in_stress.json")
IPC_MODES=("off" "on")
TEST_DURATION="${TEST_DURATION:-60}"
IMAGE_NAME="${IMAGE_NAME:-irobot-benchmark:latest}"

# Thermal thresholds (Celsius)
TEMP_LIMIT=75
TEMP_TARGET=60

get_temp() { vcgencmd measure_temp | cut -d '=' -f2 | cut -d '.' -f1; }

is_throttled() {
    local status
    status=$(vcgencmd get_throttled | cut -d '=' -f2)
    if [ "$status" == "0x0" ]; then echo "clear"; else echo "throttled"; fi
}

wait_for_cooldown() {
    local current_temp throttled_status
    current_temp=$(get_temp)
    throttled_status=$(is_throttled)
    if [ "$current_temp" -ge "$TEMP_LIMIT" ] || [ "$throttled_status" == "throttled" ]; then
        echo " HARDWARE GUARD: Pi is too hot (${current_temp}C) or throttling ($throttled_status)"
        echo " Cooling down to ${TEMP_TARGET}C..."
        while [ "$(get_temp)" -gt "$TEMP_TARGET" ] || [ "$(is_throttled)" == "throttled" ]; do
            echo " ... waiting: $(get_temp)C | Status: $(vcgencmd get_throttled)"
            sleep 15
        done
        echo " System stable. Resuming."
    else
        echo " System health: ${current_temp}C | no throttling"
    fi
}

TTY_FLAG=""; [ -t 1 ] && TTY_FLAG="-t"
mkdir -p "$HERE/results"
echo "Starting ROS 2 middleware benchmark suite"
echo "RMWs: ${RMW_LIST[*]} | IPC: ${IPC_MODES[*]} | ${TEST_DURATION}s per run"
echo "------------------------------------------"

for rmw in "${RMW_LIST[@]}"; do
    echo ">>> RMW: $rmw"
    for json in "${JSON_FILES[@]}"; do
        for ipc in "${IPC_MODES[@]}"; do
            wait_for_cooldown
            test_name="${json%.*}"
            output_dir="/tmp/results/${rmw}/${test_name}/ipc_${ipc}"
            echo " - $test_name, ipc=$ipc (${TEST_DURATION}s)"
            docker run -i $TTY_FLAG --rm \
                -e RMW_IMPLEMENTATION="$rmw" \
                -v "$HERE/topologies:/tmp/topologies" \
                -v "$HERE/results:/tmp/results" \
                "$IMAGE_NAME" \
                bash -c "source /benchmark_ws/install/setup.bash && \
                  ros2 run irobot_benchmark irobot_benchmark \
                  --topology /tmp/topologies/$json \
                  --time $TEST_DURATION \
                  --tracking on \
                  --ipc $ipc \
                  --results-dir $output_dir"
            echo "   saved: results/${rmw}/${test_name}/ipc_${ipc}/"
        done
    done
done

echo "------------------------------------------"
echo "All benchmarks complete. Next: ./parse_metrics.sh"
