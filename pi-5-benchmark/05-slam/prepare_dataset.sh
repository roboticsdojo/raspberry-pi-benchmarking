#!/usr/bin/env bash
# RDI-45 dataset prep: Intel Lab CARMEN log -> truncated log -> ROS 2 bag.
#
# Usage: ./prepare_dataset.sh [num_flaser_lines]     (default 5000)
#
# The full Intel Lab log is ~45 min; the first N FLASER lines cover the main
# corridor traversal plus a loop closure, which is what exercises pose-graph
# optimisation, while keeping runs short enough to hold thermals steady.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/config.sh"
source /opt/ros/jazzy/setup.bash

N="${1:-5000}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

if [ ! -f intel.log ]; then
    wget -nc http://www2.informatik.uni-freiburg.de/~stachnis/datasets/datasets/intel-lab/intel.log.gz
    gunzip -k intel.log.gz
fi
ls -lh intel.log   # should be a few MB

grep "^FLASER" intel.log | head -n "$N" > intel_short.log
wc -l intel_short.log

rm -rf intel_short_bag
python3 "$HERE/carmen_to_bag2.py" intel_short.log intel_short_bag
ros2 bag info intel_short_bag   # expect /scan /odom /tf /tf_static, all non-zero
