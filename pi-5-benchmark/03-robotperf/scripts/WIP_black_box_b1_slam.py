"""WORK IN PROGRESS - carried over from the procedure doc, NOT runnable as-is.

This is only a skeleton of the b1_visual_slam black-box test. It has no
`launch_setup()` / `generate_test_description()` and no SLAM node composition, so
`launch_test` will reject it. Compose the visual-SLAM graph (DataLoader ->
Playback -> SLAM node -> Monitor, as in the a1/a2/a5 scripts) before using it.

Intended sweep: publisher_upper_frequency = 20 (baseline) / 40 (stress) / 60 Hz
(saturation, 10 min, with 02-thermal-power/thermal_dvfs_log.sh running; note when
Throttled_Hex changes from 0x0 and whether TF latency spikes then). Check
LATE_PERCENTAGE > 5% in /tmp/r2b-log-*.json to flag loss of determinism.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pmic_logging import PmicLogger
from ros2_benchmark import ROS2BenchmarkConfig, ROS2BenchmarkTest

RESULTS_DIR = os.environ.get('ROBOTPERF_RESULTS_DIR', '/tmp')


class TestB1VisualSLAM(ROS2BenchmarkTest):
    config = ROS2BenchmarkConfig(
        benchmark_name='b1_visual_slam black-box',
        input_data_path='datasets/localization/r2b_galileo',
        publisher_upper_frequency=float(os.environ.get('B1_UPPER_HZ', '60.0')),
        publisher_lower_frequency=10.0,
        playback_message_buffer_size=50,
    )

    def test_benchmark(self):
        with PmicLogger(os.path.join(RESULTS_DIR, 'b1_slam_power.csv')):
            self.run_benchmark()
