# Raspberry Pi 5 Benchmarks
This repository contains scripts and files that were used to conduct benchmarks on the raspberry pi 5 4GB RAM. README includes installation of tools, and the compute & memory baseline tests as those were simply terminal commands.

## Compute and memory baseline
Data read from terminal directly and recorded into tables
1. Compute baseline
Tooling software: Sysbench
Test objectives
- Establish Peak Computational Throughput
- Assess Execution Determinism and Jitte
- Quantify Scheduling Overhead under Thread Oversubscription
Installation
```
sudo apt update
sudo apt install sysbench -y
```
Computational scaling & Thermal baseline
```
sysbench cpu --cpu-max-prime=20000 --threads=1 --time=60 run

sysbench cpu --cpu-max-prime=20000 --threads=2 --time=60 run

sysbench cpu --cpu-max-prime=20000 --threads=3 --time=60 run

sysbench cpu --cpu-max-prime=20000 --threads=4 --time=60 run
```
High Intensity Algorithmic stress
```
sysbench cpu --cpu-max-prime=200000 --threads=1 --time=10 run 

sysbench cpu --cpu-max-prime=200000 --threads=2 --time=10 run

sysbench cpu --cpu-max-prime=200000 --threads=3 --time=10 run

sysbench cpu --cpu-max-prime=200000 --threads=4 --time=10 run
```
Kernel Scheduling & Oversubscription
```
sysbench threads --threads=4 --thread-yields=1000 --thread-locks=1 --time=150 run

sysbench threads --threads=16 --thread-yields=1000 --thread-locks=1 --time=150 run

sysbench threads --threads=32 --thread-yields=1000 --thread-locks=1 --time=150 run

sysbench threads --threads=64 --thread-yields=1000 --thread-locks=1 --time=150 run
```
Data copy pasted from terminal

2. Memory Baseline
Tooling software: STREAM
Test objectives
- Quantify Peak Sustained Memory Bandwidth
- Map the Cache-to-RAM Transition
- Evaluate Memory Bus Saturation via Multi-Threading
- Assess Real-World Alignment Sensitivity

Installation
```
sudo apt update && sudo apt install build-essential git -y

wget https://www.cs.virginia.edu/stream/FTP/Code/stream.c
```
Array size = 20,000 * 24 bytes = ~480 KB (Fits inside 512KB per-core L2)
```
#This targets the L2 Cache.
gcc -O3 -fopenmp -mcpu=native -DNTIMES=10 -DSTREAM_ARRAY_SIZE=20000 stream.c -o stream_l2 

#modify no. of threads to  1, 2,3,4 and run 
export OMP_NUM_THREADS=1 && ./stream_l2
```
Array size = 75,000 elements * 24 bytes = ~1.8 MB (Fits inside 2MB shared L3) 
```
#This targets the L3 cache.
gcc -O3 -fopenmp -mcpu=native -DNTIMES=10 -DSTREAM_ARRAY_SIZE=75000 stream.c -o stream_l3 
#change no. of threads
export OMP_NUM_THREADS=1 && ./stream_l3
```
Array size = 20,000,000 * 24 bytes = ~480 MB (Forces full RAM access)
```
gcc -O3 -fopenmp -mcpu=native -DNTIMES=10 -DSTREAM_ARRAY_SIZE=20000000 stream.c -o stream_ram 
#change no. of threads
export OMP_NUM_THREADS=1 && ./stream_ram
```
Alignment and "Messy" Data Testing
```
gcc -O3 -fopenmp -mcpu=native -DNTIMES=10 -DSTREAM_ARRAY_SIZE=20000000 -DOFFSET=1024 stream.c -o stream_ram_offset 
#change no. of threads
export OMP_NUM_THREADS=1 && ./stream_ram_offset
```

## Thermal analysis
Tooling software: stress-ng
Objectives
- Characterize the Thermal Envelope
- Quantify DVFS Impact on Clock Stability
- Validate Active Cooling Efficiency
- Monitor Power Delivery Integrity

Installation
```
sudo apt update && sudo apt install -y stress-ng
```

## Full-stack performance analysis using RobotPerf 
Tooling software: RobotPerf benchmarking suite
Objectives
- Characterize Perception Pipeline Latency
- Assess Localization and SLAM Consistency
- Evaluate Coordinate Transformation (TF) Efficiency

Installation
```
sudo apt update
sudo apt install -y ros-jazzy-rosbag2-storage ros-jazzy-rosbag2-cpp
sudo apt install -y ros-jazzy-rosbag2-storage-mcap   # r2b 2024 datasets ship as .mcap
```
Repository cloning
```
# RobotPerf benchmark definitions
git clone https://github.com/robotperf/benchmarks.git
# NVIDIA's black-box test framework (RobotPerf's fork)
git clone https://github.com/robotperf/ros2_benchmark.git
# Stock image_proc (rectify/resize) — Jazzy branch
git clone -b jazzy https://github.com/ros-perception/image_pipeline.git
```

## ROS2 Middleware analysis
Tooling software: iRobot benchmark tool
Objectives
- Quantify Middleware Resource Overhead 
- Data Throughput & Latency Profiling
- Multi-Stream Concurrency & Contention
- Local IPC Delivery Integrity & Message Loss

Installation & setup
```
# Update local package index and install Docker
sudo apt update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Force group changes to take effect without a full reboot
newgrp docker
```
Repository cloning
```
# Clone the repository and initialize submodules
git clone https://github.com/irobot-ros/ros2-performance.git 
cd ros2-performance
#pull submodules
git submodule update --init --recursive --depth 1
```

## SLAM_toolbox evaluation
Tooling software: RobotPerf benchmarking suite
Objectives
- Quantify Spatial Resolution Cost
- Evaluate Trajectory Degradation (Relative Pose Error)
- Assess Algorithmic Certainty via Map Entropy
- Identify Real-Time Queue Exhaustion

Installation
```
sudo apt update
#install evaluation tool
pip install evo --break-system-packages
pip install rosbags --break-system-packages
#Download the log file data and unzip
wget http://www2.informatik.uni-freiburg.de/~stachnis/datasets/datasets/intel-lab/intel.log.gz
gunzip intel.log.gz
pip install gtsam rosbags evo Pillow numpy
sudo apt update
sudo apt install ros-jazzy-slam-toolbox ros-jazzy-nav2-map-server



