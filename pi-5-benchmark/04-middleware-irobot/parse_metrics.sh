#!/usr/bin/env bash
# Summarises results/ into Detailed_Middleware_Benchmark.txt (+ .pdf if enscript/ghostscript exist).
# Usage: ./parse_metrics.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

RESULTS_ROOT="$HERE/results"
TEMP_TEXT="Detailed_Middleware_Benchmark.txt"
FINAL_PDF="Detailed_Middleware_Benchmark.pdf"

SCENARIOS=("baseline" "frequency_stress" "size_stress" "scale_stress" "fan_in_stress")
RMWS=("rmw_fastrtps_cpp" "rmw_cyclonedds_cpp" "rmw_zenoh_cpp")
IPC_MODES=("off" "on")

{
    echo "=========================================================================================="
    echo "                 ROS 2 MIDDLEWARE COMPREHENSIVE PERFORMANCE REPORT"
    echo "                 Hardware: Raspberry Pi | Format: iRobot Summary"
    echo "                 Date: $(date)"
    echo "=========================================================================================="
    echo ""
} > "$TEMP_TEXT"

# --- SECTION 1: LATENCY & RELIABILITY ---
{
    echo "## 1. PERFORMANCE COMPARISON: LATENCY & RELIABILITY"
    echo "----------------------------------------------------------------------------------------------------------"
    printf "%-18s | %-16s | %-4s | %-10s | %-10s | %-10s\n" "Scenario" "Middleware" "IPC" "Avg Lat" "Loss %" "Received"
    echo "----------------------------------------------------------------------------------------------------------"
} >> "$TEMP_TEXT"

for test in "${SCENARIOS[@]}"; do
    for rmw in "${RMWS[@]}"; do
        for ipc in "${IPC_MODES[@]}"; do
            lat_file="$RESULTS_ROOT/$rmw/$test/ipc_${ipc}/latency_total.txt"
            if [ -f "$lat_file" ]; then
                # $1=Received, $2=Mean_us, $7=Lost
                metrics=$(awk 'NR==2 {
                    recv = $1; mean = $2; lost = $7;
                    if ((recv + lost) > 0)
                        printf "%.4f %.2f %d", mean/1000, (lost/(recv+lost))*100, recv;
                    else print "0.0000 0.00 0"
                }' "$lat_file")
                m_lat=$(echo $metrics | cut -d' ' -f1)
                loss=$(echo $metrics | cut -d' ' -f2)
                rcvd=$(echo $metrics | cut -d' ' -f3)
                printf "%-18s | %-16s | %-4s | %-10s | %-10s | %-10s\n" "$test" "$rmw" "$ipc" "${m_lat}ms" "${loss}%" "$rcvd" >> "$TEMP_TEXT"
            else
                printf "%-18s | %-16s | %-4s | %-10s | %-10s | %-10s\n" "$test" "$rmw" "$ipc" "no data" "--" "--" >> "$TEMP_TEXT"
            fi
        done
    done
    echo "----------------------------------------------------------------------------------------------------------" >> "$TEMP_TEXT"
done

# --- SECTION 2: SYSTEM RESOURCES ---
{
    echo ""
    echo "## 2. SYSTEM RESOURCE UTILIZATION (CPU & MEMORY LOAD)"
    echo "----------------------------------------------------------------------------------------------------------"
    printf "%-18s | %-16s | %-4s | %-12s | %-12s | %-12s\n" "Scenario" "Middleware" "IPC" "Avg CPU" "Peak CPU" "Peak RAM"
    echo "----------------------------------------------------------------------------------------------------------"
} >> "$TEMP_TEXT"

for test in "${SCENARIOS[@]}"; do
    for rmw in "${RMWS[@]}"; do
        for ipc in "${IPC_MODES[@]}"; do
            res_file="$RESULTS_ROOT/$rmw/$test/ipc_${ipc}/resources.txt"
            if [ -f "$res_file" ]; then
                res_metrics=$(awk '
                    {
                        if($2+0 == 0 && $2 != "0") next;
                        cpu += $2;
                        if(($2+0) > max_c) max_c=$2;
                        if(($8+0) > max_m) max_m=$8;
                        count++
                    }
                    END {
                        if(count>0) printf "%.2f %.2f %.2f", cpu/count, max_c, max_m/1024/1024;
                        else print "0.00 0.00 0.00"
                    }' "$res_file")
                avg_c=$(echo $res_metrics | cut -d' ' -f1)
                pk_c=$(echo $res_metrics | cut -d' ' -f2)
                pk_m=$(echo $res_metrics | cut -d' ' -f3)
                printf "%-18s | %-16s | %-4s | %-12s | %-12s | %-12s\n" "$test" "$rmw" "$ipc" "$avg_c%" "$pk_c%" "$pk_m MB" >> "$TEMP_TEXT"
            fi
        done
    done
    echo "----------------------------------------------------------------------------------------------------------" >> "$TEMP_TEXT"
done

echo "Text report: $HERE/$TEMP_TEXT"
if command -v enscript >/dev/null && command -v ps2pdf >/dev/null; then
    enscript -B -f Courier7 -r "$TEMP_TEXT" -p report_temp.ps 2>/dev/null
    ps2pdf report_temp.ps "$FINAL_PDF"
    rm -f report_temp.ps
    echo "PDF report:  $HERE/$FINAL_PDF"
else
    echo "(install 'enscript ghostscript' to also get the PDF)"
fi
