# Raspberry Pi 5 benchmark suite (ROS 2 Jazzy)

Reproducible benchmarks for a Raspberry Pi 5 (4 GB) used as a robotics edge controller,
running Ubuntu 24.04 + ROS 2 Jazzy. One folder per Jira ticket, one README (this file) for execution.

| Ticket | Folder | What it measures |
| --- | --- | --- |
| RDI-37 | [`01-compute-memory`](01-compute-memory) | CPU throughput/jitter/oversubscription (sysbench), cache and RAM bandwidth (STREAM) |
| RDI-39 | [`02-thermal-power`](02-thermal-power) | Time-to-throttle, clock degradation, under-voltage, fan vs no fan (stress-ng) |
| RDI-41 | [`03-robotperf`](03-robotperf) | Perception pipeline latency/throughput, black-box and grey-box (RobotPerf) |
| RDI-43 | [`04-middleware-irobot`](04-middleware-irobot) | Fast DDS vs Cyclone DDS vs Zenoh: latency, loss, CPU, RAM (iRobot ros2-performance) |
| RDI-45 | [`05-slam`](05-slam) | slam_toolbox accuracy/resource cost vs resolution, range and playback speed (evo) |

## 1. Get the code

Third-party repos are pinned as **git submodules** (see [THIRD_PARTY.md](THIRD_PARTY.md)), so clone with:

```bash
git clone --recurse-submodules <your-repo-url> pi5-ros2-benchmarks
cd pi5-ros2-benchmarks
# forgot --recurse-submodules?
git submodule update --init --recursive
```

Everything else (datasets, `stream.c`, Docker image, ROS workspace) is built or downloaded by the scripts below.

## 2. Requirements

- Raspberry Pi 5 with the **official Active Cooler** (tests 02 compares with/without it), ideally the 27 W / 5 A supply
- Ubuntu 24.04, ROS 2 Jazzy (`/opt/ros/jazzy`), `sudo`, internet access
- Disk: several GB free (Docker image, workspaces, datasets). The Docker image build creates and removes its own
  temporary swap; the RobotPerf colcon build uses 2 workers by default (`PARALLEL_WORKERS=1` if it runs out of RAM)
- Run long jobs inside `tmux` so an SSH drop doesn't kill them:

  ```bash
  tmux new -s bench        # detach: Ctrl+B then D     reattach: tmux attach -t bench
  ```

Before **every** test start from a cool, idle Pi: `vcgencmd measure_temp` (< 50 C) and
`vcgencmd get_throttled` (`throttled=0x0`). The scripts print this and some enforce it.

## 3. Setup

```bash
./setup.sh                # everything (hours on a 4 GB Pi: builds colcon workspace + Docker image)
# or only what you need:
./setup.sh compute        # sysbench, gcc
./setup.sh thermal        # stress-ng
./setup.sh robotperf      # apt deps, Jazzy patch, colcon build of RobotPerf
./setup.sh middleware     # Docker + irobot-benchmark image (-j1 build, temp swap)
./setup.sh slam           # slam_toolbox, nav2_map_server, evo, rosbags
```

Docker's group change needs a re-login (`newgrp docker`) before the middleware step.

## 4. Running the tests

All scripts write to a `results/` folder inside their own test folder (gitignored).

### RDI-37 Compute & memory baseline

```bash
cd 01-compute-memory
./run_sysbench.sh            # scaling + stress + threads (about 20 min incl. 30 s cool-downs)
./run_sysbench.sh scaling    # or: stress | threads
./run_stream.sh              # L2, L3, RAM, RAM+offset; 1-4 threads each
./run_stream.sh ram          # or: l2 | l3 | offset
```

- **sysbench**: `scaling` = prime<=20000, 1-4 threads, 60 s; `stress` = prime<=200000, 1-4 threads, 10 s
  (kept short on purpose; 60 s would throttle and measure the heatsink); `threads` = 4/16/32/64 threads
  with yields+locks, 150 s, to expose scheduler oversubscription.
- **STREAM** array sizes: 20 000 (~480 KB, L2), 75 000 (~1.8 MB, L3), 20 000 000 (~480 MB, RAM),
  RAM again with `-DOFFSET=1024` (unaligned). Threads are limited to 1-4 so context switching does not
  pollute bandwidth numbers.
- Open `btop` (CPU tab) in a second pane during each run and screenshot it by hand.

### RDI-39 Thermal throttling & power

```bash
cd 02-thermal-power
./run_thermal_test.sh active          # fan connected, 20 min stress-ng matrixprod on 4 cores
# let it cool, disconnect the fan cable, then:
./run_thermal_test.sh passive
```

Outputs `results/{active,passive}_cooling_test.csv` (seconds, temp, real ARM clock via `vcgencmd`,
core voltage, throttle bitmask) plus the stress-ng summary. The script waits for < 50 C and refuses to
start if the sticky throttle flag is not `0x0` (reboot, or `FORCE=1`).
`vcgencmd get_throttled` bit cheat-sheet: `0x1` under-voltage now, `0x2` ARM frequency capped now,
`0x4` throttled now, `0x8` soft temperature limit active now; `0x10000` / `0x20000` / `0x40000` / `0x80000` are the same four
conditions "has occurred since boot" (sticky). So `0xe0008` = frequency cap + throttling + soft temp limit have occurred,
and the soft limit is active right now.

### RDI-41 Full-stack performance (RobotPerf)

```bash
./setup.sh robotperf                  # once
source 03-robotperf/env.sh            # in every new shell
03-robotperf/download_datasets.sh perception

03-robotperf/run_blackbox.sh          # a1 / a2 / a5 + resolution sweep (scale 1.0, 0.5, 0.25)
```

Results: `03-robotperf/results/*.json` (ros2_benchmark logs; the script greps `MEAN_FRAME_RATE`) and
`*_power.csv` (PMIC samples, see Power below).

**Grey-box (LTTng) runs**

```bash
03-robotperf/run_greybox.sh a2
03-robotperf/run_greybox.sh a5
03-robotperf/run_greybox.sh a1-nodes
03-robotperf/run_greybox.sh a1-composable
03-robotperf/run_greybox.sh a1-composable-2x
03-robotperf/download_datasets.sh manipulation
03-robotperf/run_greybox.sh d1-composable-5x --pmic      # TF stress, with power logging
```

**Grey-box prerequisites (manual, NOT automated).** These upstream fixes were described only in prose in
the original procedure, so they are not in this repo. Do them once after `setup.sh` or the grey-box runs will
fail or produce bad data:

1. `benchmark_utilities`: in `<ws>/install/benchmark_utilities/lib/python3.12/site-packages/benchmark_utilities/analysis/__init__.py`,
   make `timestamp_identifier()` return `None` when a payload field is missing and have its caller skip `None`.
2. Launch files (`trace_<benchmark>.launch.py`): image_proc nodes are lazy (demand-driven). Map the input
   component to `/camera/color/image_raw` + `/camera/color/camera_info`, point Resize/Rectify at those, use the
   absolute derived `camera_info` path (e.g. `/robotperf/camera_info`), and have the output component subscribe to
   the final node's output (e.g. `/robotperf/benchmark/resize/image_raw`).
3. Keep only the four tracepoints that carry ROS header timestamps (`robotperf_image_input_cb_init/fini`,
   `robotperf_image_output_cb_init/fini`); remove the internal `image_proc_...` ones.

   These edits touch files inside `third_party/benchmarks`, so the submodule will show as modified. Either commit
   them to your own fork of `robotperf/benchmarks` and repoint the submodule, or capture them as a patch
   next to `ros2_benchmark-jazzy.patch` and extend `03-robotperf/setup.sh` to apply it.

**Power.** The Pi 5 has no INA3221. `scripts/pmic_logging.py` (black-box) and `scripts/pmic_bridge.py` (grey-box)
sample `vcgencmd pmic_read_adc` at 5-10 Hz, one row per sample (`unix_timestamp,pmic_raw`, rails joined by ` | `).
Sanity check: `grep curr 03-robotperf/results/greybox/*/pmic.csv | head`. Converting rails to watts is left to
your analysis step.

`scripts/WIP_black_box_b1_slam.py` (visual-SLAM black-box) is only a skeleton from the notes and does not run yet.

### RDI-43 Middleware (Fast DDS vs Cyclone DDS vs Zenoh)

```bash
./setup.sh middleware                       # builds irobot-benchmark:latest (long; swap is created and removed)
04-middleware-irobot/smoke_test.sh          # 30 s sanity check
04-middleware-irobot/run_matrix.sh          # 3 RMWs x 5 topologies x IPC {off,on}, 60 s each (~40 min)
04-middleware-irobot/parse_metrics.sh       # -> Detailed_Middleware_Benchmark.txt (+ .pdf)
```

Topologies (`04-middleware-irobot/topologies/`): `baseline` (10 KB @ 50 Hz, 3 subs), `frequency_stress`
(100 Hz), `size_stress` (1 MB @ 50 Hz), `scale_stress` (5 subs), `fan_in_stress` (5 pubs @ 20 Hz, 1 controller).
`run_matrix.sh` pauses whenever the SoC is >= 75 C or throttled until it is back under 60 C and clean.
`ros2 topic pub/hz` is deliberately not used: the Python CLI overhead would mask the C++ middleware cost.

### RDI-45 SLAM (slam_toolbox + evo)

```bash
./setup.sh slam
cd 05-slam
./prepare_dataset.sh            # Intel Lab log -> first 5000 FLASER lines -> ROS 2 bag
./run_benchmark.sh              # 8 runs from config.sh (res/range/tpp/playback rate), unattended, roughly 2 h
./extract_data.sh               # entropy, pose-loss efficiency, drops, evo APE/RPE, master_results.csv
```

Everything is produced in `05-slam/work/`. Run 1 (0.05 m, 30 m range, 1x) is the **relative** reference: with
no motion-capture ground truth, all errors measure degradation versus Run 1, not absolute accuracy.
Edit the matrix in `05-slam/config.sh`.

## 5. Copying results to your PC

From PowerShell / a PC terminal (not the Pi):

```bash
scp -r username@hostname.local:~/pi5-ros2-benchmarks/01-compute-memory/results .
scp -r username@hostname.local:~/pi5-ros2-benchmarks/02-thermal-power/results/*.csv .
scp -r username@hostname.local:~/pi5-ros2-benchmarks/05-slam/work .
```

## 6. Layout

```
.
├── README.md  setup.sh  THIRD_PARTY.md  .gitignore
├── common/                    lib.sh (pre-checks, cool-down), system_logger.sh (generic CPU/RAM/temp CSV logger)
├── 01-compute-memory/         run_sysbench.sh  run_stream.sh
├── 02-thermal-power/          run_thermal_test.sh  thermal_dvfs_log.sh
├── 03-robotperf/              setup.sh env.sh download_datasets.sh run_blackbox.sh run_greybox.sh
│   ├── scripts/               black_box_{a1,a2,a5}*.py  pmic_logging.py  pmic_bridge.py  WIP_black_box_b1_slam.py
│   ├── patches/               ros2_benchmark-jazzy.patch
│   └── qos_overrides.yaml
├── 04-middleware-irobot/      Dockerfile build_image.sh smoke_test.sh run_matrix.sh parse_metrics.sh topologies/
├── 05-slam/                   config.sh setup.sh prepare_dataset.sh run_benchmark.sh extract_data.sh + helpers
└── third_party/               submodules (ros2-performance, benchmarks, ros2_benchmark, image_pipeline)
```

## 7. Updating pinned upstream versions

```bash
git -C third_party/ros2-performance fetch && git -C third_party/ros2-performance checkout <commit-or-tag>
git add third_party/ros2-performance && git commit -m "Bump ros2-performance"
```

If `ros2_benchmark` changes, re-check that `03-robotperf/patches/ros2_benchmark-jazzy.patch` still applies
(`git -C third_party/ros2_benchmark apply --check ../../03-robotperf/patches/ros2_benchmark-jazzy.patch`).
