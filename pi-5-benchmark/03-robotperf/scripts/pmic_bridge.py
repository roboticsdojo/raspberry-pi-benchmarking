#!/usr/bin/env python3
"""PMIC bridge node for grey-box runs: logs `vcgencmd pmic_read_adc` at 10 Hz.

Run it in its own terminal next to the LTTng-traced pipeline:
    python3 03-robotperf/scripts/pmic_bridge.py

Output: $PMIC_LOG (default: $ROBOTPERF_RESULTS_DIR/greybox_pmic_trace.csv, else /tmp/...)
Sanity check:  grep "curr" <file> | head
"""
import os
import subprocess
import time

import rclpy
from rclpy.node import Node


class PMICBridge(Node):
    def __init__(self):
        super().__init__('pmic_bridge')
        default = os.path.join(
            os.environ.get('ROBOTPERF_RESULTS_DIR', '/tmp'), 'greybox_pmic_trace.csv')
        self.log_path = os.environ.get('PMIC_LOG', default)
        with open(self.log_path, 'w') as f:
            f.write('unix_timestamp,pmic_raw\n')
        self.get_logger().info(f'Logging PMIC to {self.log_path}')
        self.timer = self.create_timer(0.1, self.timer_callback)  # 10 Hz

    def timer_callback(self):
        raw = subprocess.check_output(['vcgencmd', 'pmic_read_adc']).decode()
        with open(self.log_path, 'a') as f:
            f.write(f"{time.time()},{' | '.join(raw.strip().splitlines())}\n")


def main(args=None):
    rclpy.init(args=args)
    node = PMICBridge()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
