#!/bin/bash
# Shared configuration for the SLAM Toolbox Pi 5 benchmark.
# Sourced by run_benchmark.sh and extract_data.sh - edit paths / the matrix here only.
set -uo pipefail

export ROS_DOMAIN_ID=42

# Static files live next to this script; everything generated goes under work/ (gitignored).
SLAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-$SLAM_DIR/work}"

BENCH_DIR="$WORK_DIR"                       # cwd for runs: trajectories, maps, slam logs land here
LOG_DIR="$WORK_DIR/logs"                    # per-run resource CSVs
BAG_IN="$WORK_DIR/intel_short_bag"
QOS_FILE="$SLAM_DIR/qos_override.yaml"
LAUNCH_FILE="$SLAM_DIR/slam_toolbox_launch.py"
LOGGER_SCRIPT="$SLAM_DIR/optimized_logger.sh"

COOLDOWN_SEC=15       # settle time between runs so heat/CPU load doesn't bleed into the next run
NODE_WAIT_TIMEOUT=20  # seconds to wait for /slam_toolbox to appear after launch

# Experimental matrix: run:resolution:range:transform_publish_period:playback_rate
RUNS=(
  "1:0.05:30.0:0.02:1.0"   # Control Ceiling
  "2:0.02:50.0:0.02:1.0"   # Stress Summation (Denser+Far)
  "3:0.10:15.0:0.02:1.0"   # Coarse (Low Signal)
  "4:0.05:5.0:0.02:1.0"    # Blind (Short Range)
  "5:0.025:30.0:0.02:1.0"  # Mid-Precision
  "6:0.05:30.0:0.05:1.0"   # Middleware Lag
  "7:0.05:30.0:0.02:2.0"   # 2x Throughput
  "8:0.05:30.0:0.02:3.0"   # 3x Throughput (Ceiling)
)
