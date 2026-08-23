# Benchmarking the Hailo-8L AI HAT+ on Raspberry Pi 5: Hailo-Accelerated vs CPU-Only YOLO Inference

## 1. Setup and Installation

### 1.1 Cloning the Repository

```bash
git clone <https://github.com/codewithlennylen/rpi5-hailo8l.git>
````

*Figure 1.1: Cloning the `rpi5-hailo8l` repository.*

*Figure 1.2: Workspace after clone.*

---

### 1.2 Install uv

```bash
curl -LsSf <https://astral.sh/uv/install.sh> | sh
```

**Why:** uv is a fast Python package/environment manager (written in Rust). It replaces pip + venv for creating and installing into the isolated Python environment needed alongside ROS 2 Jazzy — much faster dependency resolution and installs than pip.

*Figure 2.1: Installing uv.*

---

### 1.3 Install Ultralytics

```bash
pip install "ultralytics[export]"
```

Installs the Ultralytics package with export extras, needed to convert/export YOLO models into formats (e.g. ONNX) that can later be compiled to Hailo's `.hef` format.

---

### 1.4 Confirm Install & Download Dataset

```bash
uv run python3 -c "from ultralytics import YOLO; print('ok')"
python3 -c "from ultralytics.utils.downloads import download; download('<https://ultralytics.com/assets/coco2017val.zip>', dir='./datasets')"
```

**Why:** The first line confirms Ultralytics imports correctly inside the uv-managed environment. The second downloads the COCO 2017 validation set — used as the sample dataset for running/validating the benchmark model.

*Figure 4.1: Dataset download.*

---

### 1.5 Check the Dataset

*Figure 5.1: Downloaded images.*

---

### 1.6 Confirm Which Temperature Tool You Have

```bash
which vcgencmd
```

*Figure 6.1: Temperature tool.*

Run this first. It decides which version of the monitoring script below you use.

Install it if missing:

```bash
sudo apt update
sudo apt install libraspberrypi-bin
```

*Figure 6.2: Path Confirmed.*

---

### 1.7 Build the 500-Image Sample

```bash
mkdir -p ~/hailo_coco_sample
ls ~/rpi5-hailo8l/datasets/coco/images/val2017/*.jpg | shuf | head -500 | xargs -I{} cp {} ~/hailo_coco_sample/
ls ~/hailo_coco_sample | wc -l
```

Confirm it prints 500.

*Figure 7.1: Count confirmed as 500.*

---

## 2. System Monitoring

### 2.1 Write the Monitoring Script

```bash
nano ~/monitor.sh
```

Paste this below:

```bash
#!/bin/bash
echo "timestamp,cpu_temp_c,throttled,cpu_idle_pct" > ~/system_log.csv
while true; do
  ts=$(date +%s)
  temp=$(vcgencmd measure_temp | grep -oP '[\d.]+')
  throttled=$(vcgencmd get_throttled | cut -d= -f2)
  idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
  echo "$ts,$temp,$throttled,$idle" >> ~/system_log.csv
  sleep 1
done
```

Save and exit: `Ctrl+O`, Enter, `Ctrl+X`.

Logs temperature, throttling status, and CPU idle % every second while it runs.

---

## 3. Hailo-8L Pre-Flight Checks

### 3.1 Confirm the Chip

```bash
hailortcli fw-control identify
```

*Figure 7.2: Pre-flight check that the driver and chip respond correctly.*

---

### 3.2 Identify Output

```bash
hailortcli --help
```

*Figure 7.3: Full subcommand list.*

Full list of all `hailortcli` subcommands. Confirms what tools exist.

The two relevant ones are:

* `benchmark` — hardware-only speed test
* `monitor` — live stats while a model runs (needs `HAILO_MONITOR=1` set first)

---

### 3.3 Check measure-power Options

```bash
hailortcli measure-power --help
```

Shows the full options this command supports, `--duration`, `--dvm`, etc.

*Figure 7.4: measure-power --help output.*

---

### 3.4 Check Benchmark Options

```bash
hailortcli benchmark --help
```

*Figure 7.5: benchmark --help output.*

Needs a `.hef` file path as a positional argument (no `--` in front).

Key options:

* `-t` — how long to run, default 15s
* `-batch-size` — images per inference call, default 1
* `-input-files` — optional; if skipped, uses random data

---

### 3.5 Find Your `.hef` File

```bash
find ~/rpi5-hailo8l -name "*.hef"
```

Locates the compiled model file the Hailo-8L runs.

*Figure 7.6: Path found.*

---

## 4. Hardware-Only Benchmark

### 4.1 Run the Hardware-Only Benchmark

```bash
hailortcli benchmark <actual-path-here> -t 30
```

Tests the chip's raw speed directly, with no ROS 2 involved. Used as a cross-check against the pipeline benchmark.

*Figure 8.1: Command 1.*

*Figure 8.2: Command 2.*

---

### 4.2 Start the System Monitor

```bash
~/monitor.sh &
```

Runs in the background, logging temperature, throttling, and CPU idle % to `~/system_log.csv`.

*Figure 9.1: Command issued, background job started.*

---

### 4.3 Confirm It's Writing

```bash
sleep 3
tail -5 ~/system_log.csv
```

Checks that the log file already has rows.

Empty output means the script didn't start. Check with `jobs`.

*Figure 10.1: Log rows confirmed.*

---

## 5. ROS 2 Detector Setup

### 5.1 Check Running Nodes

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 node list
```

Empty output confirms no detector is currently running.

*Figure 11.1: Empty node list.*

---

### 5.2 Locate Launch Files

```bash
find ~/ros2_ws/src -name "*.launch.py"
```

Finds all available launch files in the workspace: the Hailo detector, the CPU detector, and the benchmark tool.

*Figure 12.1: Three launch files found.*

---

### 5.3 Locate Detector Package Files

```bash
find ~/rpi5-hailo8l -iname "*detect*"
```

Confirms the detector source files exist and where they live.

*Figure 13.1: Detector-related files listed.*

---

### 5.4 Confirm Package Name and Attempt Launch

```bash
ros2 pkg list | grep hailo
ros2 launch hailo_yolo_detector detector.launch.py
```

Package name confirmed as `hailo_yolo_detector` (not the folder name `hailo_detector_node`).

Launch fails:

```text
HAILO_OUT_OF_PHYSICAL_DEVICES(74)
requested: 1, found: 0
```

Means something has the chip locked, or the driver isn't seeing it.

*Figure 14.1: Launch failing with device error.*

---

### 5.5 Diagnose the Device

```bash
hailortcli scan
```

Returned `Hailo devices not found`, confirming the driver isn't seeing the chip at all, not just a busy device.

---

## 6. Hailo PCIe Driver and Kernel Fix

### 6.1 Confirm the Exact Running Kernel

```bash
uname -r
```

Should print:

```text
6.8.0-1061-raspi
```

*Figure 16.1: Running Kernel.*

---

### 6.2 Install Matching Headers for This Kernel

```bash
sudo apt update
sudo apt install linux-headers-$(uname -r)
```

---

### 6.3 Confirm the Headers Landed Correctly

```bash
ls -l /lib/modules/$(uname -r)/build
```

Should now point to a real `linux-headers-6.8.0-1061-raspi` folder, not missing or broken.

*Figure 16.2: Confirm the headers.*

---

### 6.4 Rebuild and Reconfigure the Driver Package

```bash
sudo dpkg --configure hailort-pcie-driver
```

Retries the driver's setup.

If it reports "already configured":

*Figure 16.3: Errors processing driver.*

```bash
sudo dkms autoinstall
```

Rebuilds all registered kernel modules, including the Hailo driver, against the current kernel.

---

### 6.5 Reboot to Load the Freshly Built Module

```bash
sudo reboot
```

---

### 6.6 Verify After Reboot

```bash
lsmod | grep hailo
ls /dev/hailo*
hailortcli scan
```

*Figure 16.4: Driver is loaded.*

---

## 7. Launch the Hailo Detector

### 7.1 Launch the Detector

```bash
find / -name "yolov8s.hef" 2>/dev/null
cd /home/smartai/ros2_ws/src/rpi5-hailo8l/models
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 launch hailo_yolo_detector detector.launch.py
```

Must be launched from the folder containing the `.hef` file, since the node looks for it as a relative path.

Successful output:

```text
Model input: 640x640x3, 1 output stream(s)
hailo_detector_node ready. Subscribed: /camera/image_raw  Publishing: /hailo/detections
```

*Figure 19.1: Detector loaded and ready.*

---

### 7.2 In a Second Terminal, Confirm It's Alive

```bash
source /opt/ros/jazzy/setup.bash
ros2 node list
ros2 topic list
```

*Figure 20.1: Node and topic list confirmed.*

---

## 8. Enable Live Chip Monitoring

### 8.1 Enable Live Monitoring

`hailortcli monitor` only reports data if `HAILO_MONITOR=1` is set **before** the detector launches, in the same terminal.

To use it, stop the detector first (`Ctrl+C`), then relaunch:

```bash
export HAILO_MONITOR=1
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
cd /home/smartai/ros2_ws/src/rpi5-hailo8l/models
ros2 launch hailo_yolo_detector [detector.launch.py](<http://detector.launch.py/>)
```

*Figure 21.1: Live Monitoring Initialized.*

Then in a separate terminal:

```bash
hailortcli monitor
```

*Figure 21.2: Live Monitoring.*

This step was skipped for the main run. Latency, FPS, and detection results all come from the benchmark CSV regardless. Live monitoring is a bonus view, not a requirement.

---

## 9. Run the Hailo Benchmark

Run the benchmark now, in a third terminal:

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 run hailo_benchmark_tools dataset_benchmark \
--ros-args \
-p dataset_path:=/home/smartai/hailo_coco_sample \
-p image_topic:=/camera/image_raw \
-p detections_topic:=/hailo/detections \
-p warmup_images:=20 \
-p output_csv:=~/hailo_coco_500_benchmark.csv
```

*Figure 21.3: Benchmark running.*

The experiment was done more than once but recorded two results:

### Result 1

### Result 2

---

## 10. Check Temperature and Throttling

```bash
tail -20 ~/system_log.csv
```

Shows the most recent logged rows, covering the benchmark window.

```bash
awk -F',' 'NR>1{sum+=$2; if($2>max) max=$2} END{print "avg temp:", sum/(NR-1), "max temp:", max}' ~/system_log.csv
```

Average and peak temperature across the whole logging period.

```bash
awk -F',' 'NR>1 && $3!="0x0"{print}' ~/system_log.csv
```

Checks for any throttling event. No output means it never throttled.

**Figure 22.1:** Temperature and throttling check results.

---

## 11. Confirm the Hailo Chip Sits Idle During CPU Test

```bash
hailortcli scan
```

Run while `cpu_yolo_detector` is running.

Device still shows as available, confirming nothing claimed it. The Hailo-8L was completely unused during the CPU run.

*Figure 23.1: Device shown as idle/available.*

**Note for the report:**

> CPU baseline was measured with `cpu_yolo_detector`, using Ultralytics/PyTorch inference on the Pi's CPU. The Hailo-8L driver remained loaded but idle throughout this test, since `cpu_yolo_detector` does not interface with HailoRT or the Hailo device.

---

## 12. Fix Missing Dependency

### 12.1 Check Python

```bash
which python3
python3 -c "import sys; print(sys.executable)"
```

Confirms the detector node runs under system Python.

### 12.2 Install ONNX Runtime

```bash
pip install onnxruntime --break-system-packages
```

Installs the missing module the CPU detector needs.

*Figure 24.1: Install completing.*

---

## 13. Find the ONNX Model File

```bash
find / -name "yolov8s.onnx" 2>/dev/null
```

Confirms the ONNX model's real path.

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 launch cpu_yolo_detector cpu_detector.launch.py model_path:=/full/real/path/to/yolov8s.onnx
```

`model_path` must be passed explicitly. The launch file has no default.

*Figure 25.1: Detector loading successfully.*

---

## 14. Run the CPU Benchmark

### 14.1 Terminal 1 — Launch the CPU Detector

Leave it running:

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 launch cpu_yolo_detector cpu_detector.launch.py
```

Watch for it to confirm it's ready and subscribed, same as the Hailo one did.

---

### 14.2 Terminal 2 — Confirm It's Alive

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 node list
ros2 topic list
ros2 topic info /cpu/detections -v
```

---

### 14.3 Terminal 3 — Run the Benchmark at the Correct Topic

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 run hailo_benchmark_tools dataset_benchmark \
--ros-args \
-p dataset_path:=/home/smartai/hailo_coco_sample \
-p image_topic:=/camera/image_raw \
-p detections_topic:=/cpu/detections \
-p warmup_images:=20 \
-p output_csv:=/home/smartai/cpu_only_500_benchmark.csv
```

Only `detections_topic` changes. `image_topic` stays the same since both detectors subscribe to the same camera feed.

### Test Flow for This Run

```text
yolov8s.onnx → cpu_yolo_detector → /cpu/detections → dataset_benchmark
```

The Hailo detector is not involved in this test.

*Figure 28.1: CPU benchmark running, real detections returning (not timing out).*

---

# 15. Interpreting the Temperature Readings

**Original (idle) temperature: 47.3°C**, recorded via SSH login banner before any benchmark load began. This is the baseline every other reading is compared against.

Throttling on the Pi 5 is not just "getting warm"; it is a specific firmware-triggered response that only kicks in once the SoC crosses its defined thermal limit (around 80–85°C depending on config), at which point `vcgencmd get_throttled` reports a non-zero value and the CPU frequency gets capped to cool down.

A temperature rise on its own, well below that threshold, is normal and does not count as throttling.

In both the **Hailo-8L benchmark** and the **CPU-only benchmark**, peak temperature stayed well below that threshold, and `get_throttled` returned `0x0` throughout each run.

**No throttling occurred in either test.**

---

# 16. Graphs

## 16.1 Inference Latency Comparison

*Graph 1.1: Latency Comparison.*

Graph 1.1 presents the minimum, median, mean, 95th-percentile (P95), and maximum inference latency observed for each hardware configuration over the identical 500-image dataset.

A logarithmic vertical axis was adopted, as a linear scale would render the Hailo-8L's latency values visually negligible relative to the CPU-only configuration.

The results indicate that the Hailo-8L's full observed latency range (**23.3–28.9 ms**) is narrower than the interval separating the CPU's fastest and slowest individual frames (**583–742 ms**).

This suggests the performance advantage of the accelerator is not confined to average-case behaviour, but is maintained consistently at the level of individual frames.

---

## 16.2 FPS Comparison

*Graph 1.2: Effective Throughput Comparison.*

Graph 1.2 compares effective frames-per-second (FPS) between the two configurations, with a reference line drawn at 24 FPS, a commonly cited minimum threshold for real-time performance in camera-based vision systems.

The Hailo-8L configuration exceeded this threshold by a substantial margin (**39.61 FPS**), whereas the CPU-only configuration fell markedly below it (**1.68 FPS**), a shortfall exceeding an order of magnitude.

These results support the interpretation that hardware acceleration in this context is not merely advantageous but constitutes a functional requirement for real-time operation on the evaluated platform.

---

## 16.3 Reliability Comparison

*Graph 1.3: Frame Output Stability.*

Beyond raw latency, Graph 1.3 reports the proportion of frames that were successfully processed within the benchmark's timeout window, as opposed to those that failed to return a result.

The Hailo-8L configuration completed all **480 non-warmup frames** without a single timeout.

The CPU-only configuration completed **320 of 500 frames**, with the remaining **167 (33.4%)** failing to return a detection within the allotted window.

It is noted that no individual recorded CPU latency value approached the 5-second timeout threshold, suggesting the observed failures are more plausibly attributable to intermittent scheduling or resource contention under sustained CPU load, rather than a direct function of per-frame inference time.

This distinction is presented as an identified limitation of the CPU baseline rather than a fully characterised cause, and is proposed as a direction for further investigation.

---

## 16.4 Temperature

*Graph 1.4: Temperature.*

As the system monitoring script was executed continuously across both benchmark sessions without restart, Graph 1.4 reflects temperature behaviour for the combined monitoring period rather than per-configuration measurements.

The recorded temperature rose modestly from an idle baseline of **47.3°C** to a peak of **51.0°C**, an increase of under 4°C, and no throttling event was recorded by the system firmware at any point during either benchmark run.

This finding is significant in that it excludes thermal effects as a confounding variable: the substantial disparity in latency and throughput between configurations reflects a genuine difference in computational capability rather than one pathway being constrained by thermal limits.

---

## 16.5 Detections

*Graph 1.5: Detection Yield Comparison.*

Graph 1.5 reports the average number of detections returned per successfully processed frame for each configuration, alongside the corresponding totals.

The Hailo-8L configuration yielded a marginally higher average detection rate (**4.23 detections/frame across 480 frames, 2,030 total**) than the CPU-only configuration (**3.93 detections/frame across 320 frames, 1,257 total**).

The similarity in per-frame detection rate is notable: it indicates that both configurations, when a frame was successfully processed, produced broadly comparable detection outputs.

This supports the conclusion that the performance disparity observed in Figures A–C is attributable to inference speed and reliability rather than to any material difference in detection quality between the two execution paths.

---

# 17. Hailo-8L vs CPU-Only Inference

**Table 1.1: Hailo-8L vs CPU-Only Inference**

| Metric                    |         Hailo-8L |           CPU-Only | Difference                                               |
| ------------------------- | ---------------: | -----------------: | -------------------------------------------------------- |
| Warmup frames (excluded)  |               20 |                 20 | —                                                        |
| Timed frames              |        480 / 500 |          320 / 500 | Hailo completed 160 more frames within timeout           |
| Timeouts                  |                0 |        167 (33.4%) | CPU timed out on 1 in 3 frames                           |
| Total detections          |             2030 |               1257 | —                                                        |
| Avg detections/frame      |             4.23 |               3.93 | —                                                        |
| Mean latency              |         25.25 ms |          596.02 ms | **CPU ~23.6× slower**                                    |
| Median latency            |         25.23 ms |          591.60 ms | —                                                        |
| Std deviation             |          0.74 ms |           19.82 ms | **CPU ~27× less stable**                                 |
| Min / Max latency         | 23.33 / 28.87 ms | 583.44 / 742.42 ms | —                                                        |
| P95 latency               |         26.46 ms |          626.64 ms | —                                                        |
| Effective FPS             |            39.61 |               1.68 | **Hailo ~23.6× higher throughput**                       |
| Idle baseline temperature |          47.3 °C |            47.3 °C | Shared reading, monitored continuously across both tests |
| Peak temperature          |          51.0 °C |            51.0 °C | Shared reading, not split per hardware path              |
| Throttling events         |             None |               None | No thermal factor in either                              |

---

## 17.1 Consistency Check

A repeat Hailo run returned **25.14 ms mean / 39.78 FPS / 1 timeout**, within margin of the primary run, confirming the result is stable and repeatable, not a one-off.

---

# 18. Conclusion

The Hailo-8L delivered roughly **23.6× faster mean latency and 23.6× higher throughput** than the Pi 5's CPU alone on the identical 500-image COCO dataset, run through the identical ROS 2 pipeline.

This isolates the comparison to the one variable that matters: which processor does the inference math.

The CPU result also reveals a practical limitation the Hailo-8L doesn't have: **33.4% of frames timed out** on CPU, versus zero on Hailo.

Since individual CPU latencies (max 742 ms) never approached the 5-second timeout window, the timeouts point to intermittent resource contention under sustained CPU load, worth flagging as a limitation of the CPU baseline rather than a fully understood cause.

Neither test showed thermal throttling, meaning this performance gap is a genuine compute difference, not one path being held back by heat.

At ~596 ms mean latency and under 2 FPS, CPU-only inference falls far short of real-time requirements for robotic perception.

The Hailo-8L's ~25 ms latency and ~40 FPS, by contrast, comfortably clears the real-time bar with margin to spare, confirming the AI HAT+ as a practical, necessary accelerator for real-time object detection on this platform, not merely a convenience.

```
```
## Graphs

All benchmark graphs are available in the [`Benchmaking_Graphs`](./Benchmaking_Graphs) folder.
Link: [https://github.com/roboticsdojo/raspberry-pi-benchmarking/tree/feature/RDI-173-add-updated-AI-HAT-benchmark-results/AI-HAT%2B/AI-HAT%2B_Benchmarking/Benchmaking_Graphs
]
## Blog Post

The complete benchmark setup, results, and analysis are documented in the [Raspberry Pi 5 AI Benchmark: Hailo-8L vs CPU-Only YOLO Inference](https://roboticsdojo.substack.com/p/335fe47d-dfba-40dd-a3f0-eaa2520f5638?postPreview=free&updated=2026-08-23T21%3A38%3A45.093Z&audience=everyone&free_preview=false&freemail=true).
