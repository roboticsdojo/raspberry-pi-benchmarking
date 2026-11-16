#!/usr/bin/env bash
# RDI-37 [Pi5] Compute baseline - sysbench
#
# Usage: ./run_sysbench.sh [scaling|stress|threads|all]     (default: all)
#
#   scaling : prime<=20000,  1-4 threads, 60 s each  (multi-core scaling + thermal baseline)
#   stress  : prime<=200000, 1-4 threads, 10 s each  (per-event latency; short on purpose,
#                                                     60 s here would throttle and measure the heatsink)
#   threads : yields/locks, 4/16/32/64 threads, 150 s each (scheduler oversubscription)
#
# Env: COOLDOWN (seconds between runs, default 30), RESULTS_DIR
# Monitor each run in btop (CPU tab) and screenshot it manually.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/lib.sh"
need sysbench

OUT="${RESULTS_DIR:-$SCRIPT_DIR/results}/sysbench"
mkdir -p "$OUT"
COOLDOWN="${COOLDOWN:-30}"

run() {
    local name="$1"; shift
    echo; echo ">>> sysbench $*  ->  $name.txt"
    {
        echo "# temp_before=$(soc_temp)C throttled_before=$(throttle_flags)"
        sysbench "$@" run
        echo "# temp_after=$(soc_temp)C throttled_after=$(throttle_flags)"
    } 2>&1 | tee "$OUT/$name.txt"
    cooldown "$COOLDOWN"
}

scaling() {
    for t in 1 2 3 4; do
        run "cpu_prime20000_t${t}" cpu --cpu-max-prime=20000 --threads="$t" --time=60
    done
}

stress() {
    for t in 1 2 3 4; do
        run "cpu_prime200000_t${t}" cpu --cpu-max-prime=200000 --threads="$t" --time=10
    done
}

threads() {
    for t in 4 16 32 64; do
        run "threads_t${t}" threads --threads="$t" --thread-yields=1000 --thread-locks=1 --time=150
    done
}

precheck
case "${1:-all}" in
    scaling) scaling ;;
    stress)  stress ;;
    threads) threads ;;
    all)     scaling; stress; threads ;;
    *) echo "Usage: $0 [scaling|stress|threads|all]"; exit 1 ;;
esac

echo; echo "Done. Raw output in $OUT/"
