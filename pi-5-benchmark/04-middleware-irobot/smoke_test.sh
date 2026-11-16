#!/usr/bin/env bash
# 30 s sanity run of the baseline topology on Fast DDS (checks the image works end to end).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HERE/results"
docker run --rm \
    -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    -v "$HERE/topologies:/tmp/topologies" \
    -v "$HERE/results:/tmp/results" \
    irobot-benchmark:latest \
    bash -c "source /benchmark_ws/install/setup.bash && \
      ros2 run irobot_benchmark irobot_benchmark \
        --topology /tmp/topologies/baseline.json \
        --time 30 --tracking on --ipc off \
        --results-dir /tmp/results/smoke_fastrtps"
echo "Results: $HERE/results/smoke_fastrtps"
