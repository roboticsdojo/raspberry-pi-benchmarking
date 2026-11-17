#!/usr/bin/env bash
# Downloads NVIDIA r2b 2024 datasets into 03-robotperf/assets/datasets/ (gitignored).
#
# Usage: ./download_datasets.sh [perception|localization|manipulation|all]
#   perception   -> r2b_galileo2   (a1/a2/a5 image pipeline)
#   localization -> r2b_galileo    (b1 visual SLAM)
#   manipulation -> r2b_robotarm   (d1 TF / xarm6)

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2024/versions/1/files"

fetch() {   # fetch <category> <dataset>
    local cat="$1" ds="$2" dir="$HERE/assets/datasets/$1/$2"
    mkdir -p "$dir"
    echo "==> $cat/$ds"
    wget -nc --content-disposition -O "$dir/${ds}_0.mcap"  "$BASE/$ds/${ds}_0.mcap" || true
    wget -nc --content-disposition -O "$dir/metadata.yaml" "$BASE/$ds/metadata.yaml" || true
    ls -lh "$dir"
}

case "${1:-all}" in
    perception)   fetch perception r2b_galileo2 ;;
    localization) fetch localization r2b_galileo ;;
    manipulation) fetch manipulation r2b_robotarm ;;
    all) fetch perception r2b_galileo2; fetch localization r2b_galileo; fetch manipulation r2b_robotarm ;;
    *) echo "Usage: $0 [perception|localization|manipulation|all]"; exit 1 ;;
esac
