# Hailo-8L AI HAT+ Benchmark — Raspberry Pi 5 (Phase 4)

## Objective

This phase benchmarks the performance of the **Hailo-8L AI accelerator** (Raspberry Pi AI HAT+) on a **Raspberry Pi 5**, using a ROS 2 object-detection pipeline. The benchmark measures:

- Inference latency
- Effective FPS (frames per second)
- Detection count
- Latency stability

## System Configuration

| Component | Details |
|---|---|
| Board | Raspberry Pi 5 |
| Accelerator | Hailo AI HAT+ (Hailo-8L) |
| OS | Ubuntu |
| Middleware | ROS 2 Jazzy |
| Runtime | HailoRT |
| Tools | Hailo Apps, `hailo_benchmark_tools` |
| Model | YOLOv8s (`.hef`) |

**ROS 2 topics used:**
- `/camera/image_raw` — input images
- `/hailo/detections` — output detections

## Setup

### 1. Clone the benchmark repository

```bash
cd ~/ros2_ws/src
git clone git@github.com:codewithlennylen/rpi5-hailo8l.git
```

Contains the Hailo detector node, a CPU detector, benchmarking tools, and YOLO `.hef` models (`yolov8n.hef`, `yolov8s.hef`). **YOLOv8s** was selected for this benchmark.

### 2. Add packages to the workspace

```bash
cp -r ~/ros2_ws/src/rpi5-hailo8l/ros2_ws/src/* ~/ros2_ws/src/
cd ~/ros2_ws
colcon build
source ~/ros2_ws/install/setup.bash
```

### 3. Build a test dataset

Sample images were pulled from existing Hailo example assets (pose estimation, classification, barcode detection, stereo depth, etc.) and copied into a dedicated folder:

```bash
mkdir -p ~/hailo_test_dataset
cp /path/to/example_image.jpg ~/hailo_test_dataset/
```

Dataset expanded to ~10 images. Verify count:

```bash
ls ~/hailo_test_dataset | wc -l
```

## Running the Benchmark

Source the workspace first:

```bash
source ~/ros2_ws/install/setup.bash
```

Initial run (5 warmup images) failed — the dataset only had 4 images at the time, leaving no frames for timed measurement. Warmup count was reduced and the benchmark re-run:

```bash
ros2 run hailo_benchmark_tools dataset_benchmark \
  --ros-args \
  -p dataset_path:=/home/smartai/hailo_test_dataset \
  -p image_topic:=/camera/image_raw \
  -p detections_topic:=/hailo/detections \
  -p warmup_images:=2 \
  -p output_csv:=~/hailo_benchmark.csv
```

## Pipeline Overview
Dataset Images
↓
dataset_benchmark
↓
/camera/image_raw
↓
Hailo ROS 2 Detector
↓
HailoRT
↓
Hailo-8L
↓
Neural Network Inference
↓
/hailo/detections
↓
Benchmark Measurements

> Note: this benchmarks the full **ROS 2 image-to-detection pipeline**, not the Hailo-8L chip in isolation.

## Results

| Metric | Result |
|---|---|
| Mean latency | 24.23 ms |
| Median latency | 23.53 ms |
| P95 latency | 24.82 ms |
| Minimum latency | 22.06 ms |
| Maximum latency | 28.26 ms |
| Standard deviation | 2.17 ms |
| Effective FPS | 41.27 |
| Timed frames | 6 |
| Total detections | 8 |
| Avg. detections/frame | 1.33 |
| Warmup frames (excluded) | 2 |
| Timeouts (approx.) | 3 |

### Interpretation

- **Mean latency (24.23 ms):** average time to produce a detection result per frame.
- **Effective FPS (41.27):** frames processed per second during the timed window.
- **Latency stability (σ = 2.17 ms):** low variance indicates consistent inference timing.
- **P95 latency (24.82 ms):** 95% of measured latencies fell at or below this value.
- **Detections (8 across 6 frames):** confirms the detector was reliably producing output.

### Timeouts

Approximately 3 timeouts occurred. Some dataset images originated from unrelated Hailo example applications (classification, barcode, pose estimation) rather than being curated for the active detection model, which likely contributed to missed detections.

## Limitations

- Only **6 frames** were used for the final timed calculation — a small sample size.
- The dataset mixed general Hailo example images rather than a standardized, detector-specific set.
- Results should be treated as an **initial performance validation**, not a definitive benchmark.

## Conclusion

The Hailo-8L accelerator delivered low-latency neural network inference within a Raspberry Pi 5 ROS 2 perception pipeline, achieving a mean latency of **24.23 ms** and effective throughput of **41.27 FPS**. Latency remained stable (σ = 2.17 ms, P95 = 24.82 ms), and the detector reliably produced output (8 detections across 6 timed frames).

These results indicate the Raspberry Pi 5 + Hailo-8L AI HAT+ combination is a practical, real-time, hardware-accelerated option for ROS 2 robotic perception. A larger, more diverse, and detector-specific dataset is recommended for a conclusive statistical benchmark.

## Future Work

- Expand the dataset to 100+ curated, detector-specific images.
- Reduce timeout rate by aligning test images with the trained detection classes.
- Compare against Hailo-8 (non-L) and Hailo-10H for cross-accelerator benchmarking.

## Benchmarking screenshots are available in:
- https://github.com/roboticsdojo/raspberry-pi-benchmarking/tree/feature/RDI-83-add-AI-HAT%2B_Benchamrking/AI-HAT%2B/AI-HAT%2B_Benchmarking/Benchmarking_setup_images
