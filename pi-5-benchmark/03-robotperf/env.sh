#!/usr/bin/env bash
# Source this (do not execute):  source 03-robotperf/env.sh
#
# Sets up ROS 2 Jazzy + the RobotPerf colcon workspace and points ros2_benchmark at
# this repo's dataset folder (its default path is hardcoded to NVIDIA's devcontainer).

_RP_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RP_WS="${ROBOTPERF_WS:-$HOME/robotperf_ws}"

source /opt/ros/jazzy/setup.bash
if [ -f "$_RP_WS/install/setup.bash" ]; then
    source "$_RP_WS/install/setup.bash"
else
    echo "WARNING: $_RP_WS/install/setup.bash not found - run 03-robotperf/setup.sh first" >&2
fi

export ROS2_BENCHMARK_OVERRIDE_ASSETS_ROOT="$_RP_HERE/assets"
export ROBOTPERF_RESULTS_DIR="${ROBOTPERF_RESULTS_DIR:-$_RP_HERE/results}"
mkdir -p "$ROBOTPERF_RESULTS_DIR"

unset _RP_HERE _RP_WS
