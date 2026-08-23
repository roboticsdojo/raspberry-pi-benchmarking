# Raspberry Pi AI HAT+ Setup and Benchmarking

## Overview

This documentation provides a complete guide for setting up and benchmarking the **Raspberry Pi AI HAT+** on a **Raspberry Pi 5 running Ubuntu 24.04**.

The process is divided into three stages:

1. **Hardware Setup** – Install and connect the AI HAT+ to the Raspberry Pi 5.
2. **Software Setup** – Install and configure ROS 2 Jazzy, HailoRT, the PCIe driver, Python bindings, and the required Hailo software.
3. **Benchmarking** – Run the ROS 2 image-to-detection pipeline and measure its performance when using the Hailo-8L accelerator.

Follow the stages **in order**.

---

# Setup and Benchmarking Flow

```text
                    Raspberry Pi 5
                         │
                         ▼
               ┌───────────────────┐
               │   Hardware Setup  │
               │                   │
               │ Install AI HAT+   │
               │ GPIO + PCIe       │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │   Software Setup  │
               │                   │
               │ Ubuntu 24.04      │
               │ ROS 2 Jazzy       │
               │ HailoRT           │
               │ PCIe Driver       │
               │ Python Bindings   │
               │ Hailo Applications│
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │ Device Verification│
               │                   │
               │ /dev/hailo0       │
               │ hailortcli         │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │    Benchmarking   │
               │                   │
               │ Image              │
               │   ↓                │
               │ ROS 2 Pipeline     │
               │   ↓                │
               │ Hailo-8L           │
               │   ↓                │
               │ Detection          │
               └─────────┬─────────┘
                         │
                         ▼
                  Performance
                    Results
```

---

# 1. Hardware Setup

Start here if the AI HAT+ has not yet been installed on the Raspberry Pi 5.

This section covers:

- AI HAT+ introduction and overview
- AI HAT+ vs AI HAT+ 2
- Hardware requirements
- AI HAT+ components
- Unboxing
- Mounting hardware
- GPIO header installation
- PCIe ribbon cable connection
- AI HAT+ mounting and securing
- Hardware installation verification
- Hardware troubleshooting

### Follow this guide first:

**[AI HAT+ Hardware Setup](AI-HAT+_Hardware_Setup/README.md)**

Supporting hardware installation images are located in:

```text
AI-HAT+_Hardware_Setup/Hardware_setup_images/
```

**Do not proceed to the software setup until the AI HAT+ is physically installed and connected correctly.**

---

# 2. Software Setup

After completing the hardware installation, configure the Raspberry Pi 5 software environment.

The software setup uses:

- Ubuntu 24.04
- Raspberry Pi 5
- ROS 2 Jazzy
- HailoRT
- HailoRT PCIe Driver
- HailoRT Python Binding
- TAPPAS Core
- Hailo applications
- Python virtual environment

The software guide takes the system from the initial Ubuntu configuration through Hailo device verification.

It covers:

- Installing ROS 2 Jazzy
- Adding the ROS 2 repository
- Verifying the ROS installation
- Obtaining the required Hailo packages
- Transferring packages to the Raspberry Pi
- Installing the Hailo PCIe driver
- Installing HailoRT
- Installing the required kernel headers
- Configuring the PCIe driver
- Verifying `/dev/hailo0`
- Using `hailortcli`
- Creating the Python environment
- Installing the HailoRT Python binding
- Installing Hailo applications
- Running the Hailo post-installation procedure
- Troubleshooting installation issues

### Follow this guide second:

**[AI HAT+ Software Setup](AI-HAT+_Software__Setup/README.md)**

Supporting software installation screenshots are located in:

```text
AI-HAT+_Software__Setup/Software_setup_images/
```

**Do not proceed to benchmarking until the Hailo device has been successfully detected and the software environment is working.**

---

# 3. Verify the AI HAT+

Before running the benchmark, confirm that the Raspberry Pi can communicate with the Hailo accelerator.

Check for the Hailo device:

```bash
ls /dev/hailo*
```

The expected device is:

```text
/dev/hailo0
```

Then verify the accelerator:

```bash
hailortcli fw-control identify
```

The command should return information about the connected Hailo accelerator.

If the device is not detected, return to the:

**[AI HAT+ Software Setup](AI-HAT+_Software__Setup/README.md)**

and troubleshoot the driver, kernel, and HailoRT installation before continuing.

---

# 4. Benchmarking

The final stage measures the performance of the **complete ROS 2 image-to-detection pipeline** running on the Raspberry Pi 5 with the Hailo-8L AI accelerator.

> **Note:** This benchmark measures the full **ROS 2 image-to-detection pipeline**, not the Hailo-8L chip in isolation.

The pipeline processes an image through the ROS 2 perception system and produces a detection result using the Hailo-8L for accelerated neural network inference.

The benchmark measures:

- Mean latency
- Median latency
- P95 latency
- Minimum latency
- Maximum latency
- Standard deviation
- Effective FPS
- Timed frames
- Total detections
- Average detections per frame
- Warmup frames
- Timeouts

### Benchmark workflow

```text
Input Image
     │
     ▼
ROS 2 Image Pipeline
     │
     ▼
Hailo-8L Inference
     │
     ▼
Detection Output
     │
     ▼
Latency / FPS / Detection Metrics
```

### Follow this guide third:

**[AI HAT+ Benchmarking](AI-HAT+_Benchmarking/README.md)**

Supporting benchmark screenshots, logs, graphs, and other visual material are located in:

```text
AI-HAT+_Benchmarking/Benchmarking_setup_images/
```

---

# 5. Benchmark Results

The initial benchmark produced the following results:

| Metric | Result |
|---|---:|
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

- **Mean latency (24.23 ms):** Average time to produce a detection result per frame.
- **Effective FPS (41.27):** Frames processed per second during the timed window.
- **Latency stability (σ = 2.17 ms):** The low variance indicates relatively consistent inference timing.
- **P95 latency (24.82 ms):** 95% of measured latencies fell at or below this value.
- **Detections (8 across 6 frames):** Confirms that the detector produced output during the benchmark.

### Timeouts

Approximately three timeouts occurred.

Some dataset images originated from unrelated Hailo example applications, including classification, barcode, and pose-estimation examples, rather than being curated specifically for the active detection model. This likely contributed to missed detections.

---

# 6. Benchmark Limitations

The initial benchmark has several limitations:

- Only **6 frames** were used for the final timed calculation.
- The dataset contained a mixture of general Hailo example images rather than a standardized, detector-specific dataset.
- Approximately three timeouts occurred.
- The results should therefore be treated as an **initial performance validation**, rather than a definitive statistical benchmark.

For a more reliable benchmark, a larger and detector-specific dataset should be used.

---

# 7. Conclusion

The Hailo-8L accelerator delivered low-latency neural network inference within a Raspberry Pi 5 ROS 2 perception pipeline.

The initial benchmark achieved:

- **24.23 ms mean latency**
- **41.27 effective FPS**
- **2.17 ms standard deviation**
- **24.82 ms P95 latency**

These results indicate that the Raspberry Pi 5 + Hailo-8L AI HAT+ combination can provide practical hardware-accelerated inference for ROS 2 robotic perception.

However, the benchmark should be repeated with a larger and detector-specific dataset before drawing definitive performance conclusions.

---

# 8. Future Work

Future benchmarking work should include:

- Expand the dataset to **100+ curated, detector-specific images**.
- Reduce timeout rates by aligning test images with the trained detection classes.
- Repeat the benchmark with a larger sample size.
- Compare the Hailo-8L against other Hailo accelerators where hardware is available.
- Compare performance metrics across different AI models and workloads.

---

# 9. Documentation Structure

The repository is organized so that each stage contains its own detailed guide and supporting images.

```text
AI-HAT+/
│
├── README.md
│
├── AI-HAT+_Hardware_Setup/
│   ├── README.md
│   └── Hardware_setup_images/
│
├── AI-HAT+_Software__Setup/
│   ├── README.md
│   └── Software_setup_images/
│
└── AI-HAT+_Benchmarking/
    ├── README.md
    └── Benchmarking_setup_images/
```

### Hardware

```text
AI-HAT+_Hardware_Setup/
```

Contains the physical installation procedure and hardware images.

### Software

```text
AI-HAT+_Software__Setup/
```

Contains the Ubuntu 24.04, ROS 2 Jazzy, Hailo software, driver, runtime, Python environment, and verification procedures.

### Benchmarking

```text
AI-HAT+_Benchmarking/
```

Contains the benchmark procedure, commands, results, analysis, limitations, and supporting benchmark images.

---

# 10. Recommended Order

If you are setting up the AI HAT+ from scratch, follow this exact order:

### Step 1 — Hardware

**[Open the Hardware Setup Guide](AI-HAT+_Hardware_Setup/README.md)**

Install and connect the AI HAT+.

↓

### Step 2 — Software

**[Open the Software Setup Guide](AI-HAT+_Software__Setup/README.md)**

Install Ubuntu 24.04 software requirements, ROS 2 Jazzy, HailoRT, drivers, Python bindings, and Hailo applications.

↓

### Step 3 — Verify

Confirm:

```bash
ls /dev/hailo*
```

and:

```bash
hailortcli fw-control identify
```

↓

### Step 4 — Benchmark

**[Open the Benchmarking Guide](AI-HAT+_Benchmarking/README.md)**

Run the ROS 2 image-to-detection benchmark and collect the performance metrics.

↓

### Step 5 — Analyze

Review the latency, FPS, detection, timeout, and other benchmark results.

---

## Complete Workflow

**Hardware Setup → Software Setup → Hailo Verification → ROS 2 Image-to-Detection Benchmark → Results → Analysis**
