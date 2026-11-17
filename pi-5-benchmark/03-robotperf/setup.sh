#!/usr/bin/env bash
# RDI-41 one-time setup: apt deps, submodules, Jazzy patch, colcon build.
#
# Builds the pinned submodules in <repo>/third_party (benchmarks, ros2_benchmark,
# image_pipeline) into a colcon workspace at $ROBOTPERF_WS (default ~/robotperf_ws).
#
# Env: ROBOTPERF_WS, PARALLEL_WORKERS (default 2; this builds image_pipeline on a 4 GB Pi,
#      raise it only if you have swap and patience)

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
TP="$REPO/third_party"
WS="${ROBOTPERF_WS:-$HOME/robotperf_ws}"

source /opt/ros/jazzy/setup.bash

echo "==> apt dependencies"
sudo apt update
sudo apt install -y \
    python3-colcon-common-extensions python3-rosdep \
    ros-jazzy-rosbag2-storage ros-jazzy-rosbag2-cpp ros-jazzy-rosbag2-storage-mcap \
    lttng-modules-dkms lttng-tools liblttng-ust-dev \
    ros-jazzy-tracetools ros-jazzy-ros2trace ros-jazzy-tracetools-launch \
    babeltrace2 python3-bt2
python3 -m pip install "bokeh<3" --break-system-packages
sudo usermod -aG tracing "$USER"   # takes effect after re-login

echo "==> submodules"
git -C "$REPO" submodule update --init third_party/benchmarks third_party/ros2_benchmark third_party/image_pipeline

echo "==> patching ros2_benchmark for Jazzy (idempotent)"
PATCH="$HERE/patches/ros2_benchmark-jazzy.patch"
if git -C "$TP/ros2_benchmark" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "    already applied"
else
    git -C "$TP/ros2_benchmark" apply "$PATCH"
    echo "    applied"
fi

echo "==> rosdep"
[ -f /etc/ros/rosdep/sources.list.d/20-default.list ] || sudo rosdep init
rosdep update
rosdep install --from-paths "$TP/benchmarks" "$TP/ros2_benchmark" "$TP/image_pipeline" \
    --ignore-src -r -y

echo "==> colcon build -> $WS"
mkdir -p "$WS"
cd "$WS"
colcon build --parallel-workers "${PARALLEL_WORKERS:-2}" \
    --base-paths "$TP/benchmarks" "$TP/ros2_benchmark" "$TP/image_pipeline" \
    --cmake-args -DCMAKE_BUILD_TYPE=Release

echo
echo "Done. Next:  source $HERE/env.sh && $HERE/download_datasets.sh all"
echo "NOTE: log out/in (or 'newgrp tracing') so the 'tracing' group applies before grey-box runs."
