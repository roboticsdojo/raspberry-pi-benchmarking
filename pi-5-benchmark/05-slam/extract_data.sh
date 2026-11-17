#!/bin/bash
# extract_data.sh
#
# Post-processing pipeline over the outputs of run_benchmark.sh:
#   1. Map normalization + Shannon entropy (crispness)
#   2. Throughput / pose-loss efficiency vs. the Run-1 baseline
#   3. Dropped-message counts from the SLAM logs
#   4. EVO trajectory overlay + APE/RPE comparison tables and plots
#   5. A single master_results.csv rolling 1-3 together for reporting
#
# Run 1 is the "relative ground truth" (least constrained run). There is no
# external ground truth, so all errors are degradation relative to Run 1,
# not absolute accuracy against the real world.
#
# Usage: ./extract_data.sh      (outputs in work/)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
cd "$BENCH_DIR" || { echo "ERROR: $BENCH_DIR not found"; exit 1; }

echo "--- Checking dependencies ---"
pip install evo rosbags numpy Pillow --break-system-packages -q
command -v convert >/dev/null || sudo apt install -y imagemagick

# --- 1. Map Entropy (crispness) ---------------------------------------------
echo "--- Normalizing maps and computing entropy ---"
for i in $(seq 1 8); do
  if [ -f "map_run${i}.pgm" ]; then
    convert "map_run${i}.pgm" -trim -gravity center -background "#cdcdcd" \
      -extent 1000x1000 "map_run${i}_norm.pgm"
  fi
done
# Entropy must run on the *normalized* maps (map_run*_norm.pgm) - running it on
# the raw, uncropped originals defeats the point of normalizing them first.
python3 "$SCRIPT_DIR/map_entropy.py" map_run*_norm.pgm > map_entropy_results.txt
cat map_entropy_results.txt

# --- 2. Throughput & Pose Loss ----------------------------------------------
echo "--- Computing throughput / pose-loss efficiency ---"
echo "--- Relative Processing Efficiency (Baseline = Run 1) ---" > throughput_results.txt
if [ ! -s run1.tum ]; then
  echo "ERROR: run1.tum (baseline) missing - cannot compute efficiency." | tee -a throughput_results.txt
else
  BASE_POSES=$(wc -l < run1.tum)
  for i in $(seq 1 8); do
    if [ -s "run${i}.tum" ]; then
      POSES=$(wc -l < "run${i}.tum")
      EFFICIENCY=$(awk -v p="$POSES" -v b="$BASE_POSES" 'BEGIN{printf "%.2f", (p/b)*100}')
      LOST=$((BASE_POSES - POSES))
      echo "Run $i: Efficiency = ${EFFICIENCY}% | Poses Saved = $POSES ($LOST lost vs baseline)" \
        | tee -a throughput_results.txt
    fi
  done
fi

# --- 3. Dropped Message Counts ----------------------------------------------
echo "--- Counting dropped messages per run ---"
echo "--- Message Drop Counts per Run ---" > dropped_messages.txt
for i in $(seq 1 8); do
  if [ -f "run${i}_slam_log.txt" ]; then
    DROPS=$(grep -E -c -i "(discarding message|queue is full|dropped|buffer.*full|exceed)" "run${i}_slam_log.txt" || true)
    echo "Run $i: $DROPS dropped messages" | tee -a dropped_messages.txt
  fi
done

# --- 4. EVO Trajectory & Error Analysis -------------------------------------
echo "--- Running EVO trajectory/error analysis ---"
if [ -s run1.tum ]; then
  cp -f run1.tum reference.tum

  evo_traj tum run1.tum run2.tum run3.tum run4.tum run5.tum run6.tum run7.tum run8.tum \
    --plot_mode xy --save_plot 2D_Trajectory_Overlay.png

  for i in $(seq 2 6); do
    [ -s "run${i}.tum" ] || continue
    evo_ape tum reference.tum "run${i}.tum" --align --t_max_diff 0.05 --save_results "ate_run${i}.zip"
    evo_rpe tum reference.tum "run${i}.tum" --align --delta 1.0 --delta_unit m --save_results "rpe_run${i}.zip"
  done
  # Runs 7/8 play back at 2x/3x, so pose timestamps land further apart under
  # load - loosen the matching window or evo_ape/evo_rpe will drop most pairs.
  for i in 7 8; do
    [ -s "run${i}.tum" ] || continue
    evo_ape tum reference.tum "run${i}.tum" --align --t_max_diff 10.0 --save_results "ate_run${i}.zip"
    evo_rpe tum reference.tum "run${i}.tum" --align --t_max_diff 10.0 --delta 1.0 --delta_unit m --save_results "rpe_run${i}.zip"
  done

  evo_res ate_run*.zip -p --save_table ate_comparison.csv --save_plot APE_Comparison_Plot.png
  evo_res rpe_run*.zip -p --save_table rpe_comparison.csv --save_plot RPE_Comparison_Plot.png
else
  echo "WARNING: run1.tum missing - skipping EVO analysis." >&2
fi

# --- 5. Roll everything into one master CSV ---------------------------------
echo "--- Building master_results.csv ---"
{
  echo "Run,Resolution,Range,TPP,Rate,Entropy_bits,Efficiency_pct,PosesSaved,PosesLost,DroppedMsgs"
  for entry in "${RUNS[@]}"; do
    IFS=':' read -r RUN RES RANGE TPP RATE <<< "$entry"
    ENTROPY=$(grep "map_run${RUN}_norm.pgm" map_entropy_results.txt 2>/dev/null | awk -F'|' '{print $2}' | xargs)
    EFF_LINE=$(grep "^Run ${RUN}:" throughput_results.txt 2>/dev/null)
    EFF=$(echo "$EFF_LINE" | grep -oE 'Efficiency = [0-9.]+' | awk '{print $3}')
    SAVED=$(echo "$EFF_LINE" | grep -oE 'Poses Saved = [0-9]+' | awk '{print $4}')
    LOST=$(echo "$EFF_LINE" | grep -oE '\(-?[0-9]+ lost' | tr -d '(' | awk '{print $1}')
    DROPS=$(grep "^Run ${RUN}:" dropped_messages.txt 2>/dev/null | awk '{print $3}')
    echo "${RUN},${RES},${RANGE},${TPP},${RATE},${ENTROPY:-NA},${EFF:-NA},${SAVED:-NA},${LOST:-NA},${DROPS:-NA}"
  done
} > master_results.csv
cat master_results.csv

echo ""
echo "Done. Key outputs in $BENCH_DIR:"
echo "  master_results.csv        - per-run rollup (entropy, efficiency, drops)"
echo "  ate_comparison.csv/.png   - Absolute Pose Error vs. Run 1 baseline"
echo "  rpe_comparison.csv/.png   - Relative Pose Error vs. Run 1 baseline"
echo "  2D_Trajectory_Overlay.png - all 8 trajectories plotted together"
echo "  map_run*_norm.pgm         - normalized maps for the visual report"
echo "  logs/run*_resource.csv    - CPU/RAM/temp/clock per run"
