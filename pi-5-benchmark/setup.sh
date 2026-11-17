#!/usr/bin/env bash
# One-time dependency setup for the whole repo (or one test).
#
# Usage: ./setup.sh [all|compute|thermal|robotperf|middleware|slam]     (default: all)
#
# Assumes Ubuntu 24.04 + ROS 2 Jazzy already installed on the Pi 5, and sudo access.
# 'all' builds ROS workspaces and a Docker image: expect hours on a 4 GB Pi.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> fetching pinned third-party sources (submodules)"
git -C "$HERE" submodule update --init --recursive --depth 1 \
    || echo "WARNING: submodule init failed (offline?). Re-run later or: git submodule update --init --recursive"

common() {
    sudo apt update
    sudo apt install -y build-essential git wget tmux btop sysstat
}

compute()    { sudo apt install -y sysbench; }
thermal()    { sudo apt install -y stress-ng; }
robotperf()  { "$HERE/03-robotperf/setup.sh"; }
middleware() {
    if ! command -v docker >/dev/null; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker "$USER"
        echo "Docker installed. Log out/in (or 'newgrp docker'), then re-run: ./setup.sh middleware"
        return 0
    fi
    sudo apt install -y enscript ghostscript   # for the PDF report
    "$HERE/04-middleware-irobot/build_image.sh"
}
slam()       { "$HERE/05-slam/setup.sh"; }

case "${1:-all}" in
    compute)    common; compute ;;
    thermal)    common; thermal ;;
    robotperf)  common; robotperf ;;
    middleware) common; middleware ;;
    slam)       common; slam ;;
    all)        common; compute; thermal; slam; robotperf; middleware ;;
    *) echo "Usage: $0 [all|compute|thermal|robotperf|middleware|slam]"; exit 1 ;;
esac
echo "Setup ($1) finished."
