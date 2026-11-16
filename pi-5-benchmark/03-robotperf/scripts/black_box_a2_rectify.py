"""Black-box test: a2_rectify (Rectify only) on r2b_galileo2.

Run:  launch_test 03-robotperf/scripts/black_box_a2_rectify.py
Env:  ROBOTPERF_RESULTS_DIR   where the PMIC power CSV is written (default /tmp)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode
from pmic_logging import PmicLogger
from ros2_benchmark import ROS2BenchmarkConfig, ROS2BenchmarkTest

ROSBAG_PATH = 'datasets/perception/r2b_galileo2'
RESULTS_DIR = os.environ.get('ROBOTPERF_RESULTS_DIR', '/tmp')


def launch_setup(container_prefix, container_sigterm_timeout):
    ns = TestA2Rectify.generate_namespace()

    data_loader_node = ComposableNode(
        name='DataLoaderNode',
        namespace=ns,
        package='ros2_benchmark',
        plugin='ros2_benchmark::DataLoaderNode',
        remappings=[
            ('camera/color/image_raw', 'data_loader/image_raw'),
            ('camera/color/camera_info', 'data_loader/camera_info'),
        ]
    )

    playback_node = ComposableNode(
        name='PlaybackNode',
        namespace=ns,
        package='ros2_benchmark',
        plugin='ros2_benchmark::PlaybackNode',
        parameters=[{
            'data_formats': [
                'sensor_msgs/msg/Image',
                'sensor_msgs/msg/CameraInfo',
            ],
        }],
        remappings=[
            ('buffer/input0', 'data_loader/image_raw'),
            ('input0', 'image'),
            ('buffer/input1', 'data_loader/camera_info'),
            ('input1', 'camera_info'),
        ]
    )

    rectify_node = ComposableNode(
        name='RectifyNode',
        namespace=ns,
        package='image_proc',
        plugin='image_proc::RectifyNode',
        remappings=[
            ('image', 'image'),
            ('camera_info', 'camera_info'),
            ('image_rect', 'output'),
        ]
    )

    monitor_node = ComposableNode(
        name='MonitorNode',
        namespace=ns,
        package='ros2_benchmark',
        plugin='ros2_benchmark::MonitorNode',
        parameters=[{
            'monitor_data_format': 'sensor_msgs/msg/Image',
        }],
        remappings=[('output', 'output')]
    )

    composable_node_container = ComposableNodeContainer(
        name='container',
        namespace=ns,
        package='rclcpp_components',
        executable='component_container_mt',
        prefix=container_prefix,
        sigterm_timeout=container_sigterm_timeout,
        composable_node_descriptions=[
            data_loader_node, playback_node, rectify_node, monitor_node,
        ],
        output='screen'
    )
    return [composable_node_container]


def generate_test_description():
    return TestA2Rectify.generate_test_description_with_nsys(launch_setup)


class TestA2Rectify(ROS2BenchmarkTest):
    """Black-box test for a2_rectify on r2b_galileo2."""

    config = ROS2BenchmarkConfig(
        benchmark_name='a2_rectify black-box benchmark',
        session_name='a2_rectify_blackbox',
        input_data_path=ROSBAG_PATH,
        publisher_upper_frequency=100.0,
        publisher_lower_frequency=10.0,
        playback_message_buffer_size=10,
    )

    def test_benchmark(self):
        power_log = os.path.join(RESULTS_DIR, f'{self.config.session_name}_power.csv')
        with PmicLogger(power_log):
            self.run_benchmark()
