#!/usr/bin/env bash
# RDI-43 one-time setup: build the irobot-benchmark:latest Docker image.
#
#   1. init ros2-performance submodule (+ its nested json/cxxopts)
#   2. temporary swap (compiling the templated C++ on a 4 GB Pi triggers the OOM killer)
#   3. docker build base image (ROS Jazzy + Fast DDS + Cyclone DDS + Zenoh RMWs)
#   4. compile ros2-performance inside a container with ONE worker (-j1), commit as :latest
#
# Prereq: Docker installed and usable without sudo (curl -fsSL https://get.docker.com | sh;
#         sudo usermod -aG docker $USER; re-login).
#
# Env: SWAP_SIZE (default 4G), KEEP_SWAP=1 to leave the swapfile enabled afterwards.
# NOTE: the original procedure said "4 Gigabyte" in its comment but ran fallocate -l 1G.
#       Default here is 4G; use SWAP_SIZE=1G if disk is tight and 1G worked for you before.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
CTX="$REPO/third_party/ros2-performance"
SWAP_SIZE="${SWAP_SIZE:-4G}"
SWAPFILE=/swapfile
CONTAINER=compiling_temp_container

command -v docker >/dev/null || { echo "ERROR: docker not installed"; exit 1; }

echo "==> submodules"
git -C "$REPO" submodule update --init --recursive --depth 1 third_party/ros2-performance

echo "==> swap ($SWAP_SIZE at $SWAPFILE)"
if [ -f "$SWAPFILE" ]; then
    sudo swapoff "$SWAPFILE" 2>/dev/null || true
    sudo rm -f "$SWAPFILE"
fi
sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE"
sudo chmod 600 "$SWAPFILE"
sudo mkswap "$SWAPFILE" >/dev/null
sudo swapon "$SWAPFILE"
free -h

echo "==> docker build (base image)"
docker build --network=host -f "$HERE/Dockerfile" -t irobot-benchmark:base "$CTX"

echo "==> verify all three RMWs are present"
docker run --rm irobot-benchmark:base bash -c \
    "source /opt/ros/jazzy/setup.bash && ros2 pkg list | grep -E 'rmw_(fastrtps|cyclonedds|zenoh)_cpp'"

echo "==> compile ros2-performance (single worker; this takes a long time on a Pi)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
# The key-refresh / --allow-unauthenticated line is carried over from the original
# procedure (workaround for the apt signature errors in the base image).
docker run --name "$CONTAINER" irobot-benchmark:base bash -c '
    set -e
    cd /benchmark_ws
    source /opt/ros/jazzy/setup.bash
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
    apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true
    apt-get install -y --allow-unauthenticated ubuntu-keyring ca-certificates
    apt-get update
    apt-get install -y lld clang
    MAKEFLAGS="-j1" colcon build --parallel-workers 1 \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-g0" -DCMAKE_EXPORT_COMPILE_COMMANDS=OFF
'

echo "==> commit image + clean up"
docker commit "$CONTAINER" irobot-benchmark:latest
docker rm "$CONTAINER"

if [ "${KEEP_SWAP:-0}" != "1" ]; then
    sudo swapoff "$SWAPFILE" && sudo rm -f "$SWAPFILE"
    echo "swap removed (KEEP_SWAP=1 to keep it)"
fi

echo "==> verify"
docker images irobot-benchmark
docker run --rm irobot-benchmark:latest bash -c \
    "source /benchmark_ws/install/setup.bash && ros2 pkg list | grep -E 'performance|benchmark'"
echo "Done. Quick smoke test:  $HERE/smoke_test.sh"
