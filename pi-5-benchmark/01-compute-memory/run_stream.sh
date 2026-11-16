#!/usr/bin/env bash
# RDI-37 [Pi5] Memory baseline - STREAM
#
# Usage: ./run_stream.sh [l2|l3|ram|offset|all]     (default: all)
#
#   l2     : 20,000 elements    (~480 KB, fits per-core L2)
#   l3     : 75,000 elements    (~1.8 MB, fits shared L3)
#   ram    : 20,000,000 elem.   (~480 MB, forces DRAM)
#   offset : as ram, with -DOFFSET=1024 (unaligned/"messy" access)
#
# Each variant is run with OMP_NUM_THREADS = 1,2,3,4 only. More threads than
# cores would add context-switch latency and pollute the bandwidth numbers.
#
# stream.c is downloaded on first run (not vendored; see its own license header).
# Env: COOLDOWN (default 10), RESULTS_DIR

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/lib.sh"
need gcc

BUILD="$SCRIPT_DIR/build"
OUT="${RESULTS_DIR:-$SCRIPT_DIR/results}/stream"
mkdir -p "$BUILD" "$OUT"
COOLDOWN="${COOLDOWN:-10}"

if [ ! -f "$BUILD/stream.c" ]; then
    need wget
    wget -q -O "$BUILD/stream.c" https://www.cs.virginia.edu/stream/FTP/Code/stream.c \
        || { echo "ERROR: could not download stream.c - place it at $BUILD/stream.c manually"; exit 1; }
fi

CFLAGS_COMMON=(-O3 -fopenmp -mcpu=native -DNTIMES=10)

build() {   # build <variant> <array_size> [extra flags...]
    local name="$1" size="$2"; shift 2
    gcc "${CFLAGS_COMMON[@]}" -DSTREAM_ARRAY_SIZE="$size" "$@" "$BUILD/stream.c" -o "$BUILD/stream_$name"
}

run_variant() {
    local name="$1"
    for t in 1 2 3 4; do
        echo; echo ">>> stream_$name  OMP_NUM_THREADS=$t"
        OMP_NUM_THREADS="$t" "$BUILD/stream_$name" 2>&1 | tee "$OUT/${name}_t${t}.txt"
        cooldown "$COOLDOWN"
    done
}

do_one() {
    case "$1" in
        l2)     build l2 20000;                          run_variant l2 ;;
        l3)     build l3 75000;                          run_variant l3 ;;
        ram)    build ram 20000000;                      run_variant ram ;;
        offset) build ram_offset 20000000 -DOFFSET=1024; run_variant ram_offset ;;
        *) echo "Usage: $0 [l2|l3|ram|offset|all]"; exit 1 ;;
    esac
}

precheck
if [ "${1:-all}" = "all" ]; then
    for v in l2 l3 ram offset; do do_one "$v"; done
else
    do_one "$1"
fi
echo; echo "Done. Raw output in $OUT/"
