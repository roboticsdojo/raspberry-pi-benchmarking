#!/usr/bin/env bash
# RDI-45 one-time setup: apt + pip dependencies.
# (The original notes also pip-installed gtsam; nothing in these scripts uses it, so it is omitted.)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo apt update
sudo apt install -y ros-jazzy-slam-toolbox ros-jazzy-nav2-map-server imagemagick
python3 -m pip install -r "$HERE/requirements.txt" --break-system-packages
echo "Done. Next: ./prepare_dataset.sh"
