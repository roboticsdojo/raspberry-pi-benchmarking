from launch import LaunchDescription
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue
from launch.substitutions import LaunchConfiguration
from launch.actions import DeclareLaunchArgument


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('res', default_value='0.05'),
        DeclareLaunchArgument('range', default_value='30.0'),
        DeclareLaunchArgument('tpp', default_value='0.02'),
        Node(package='slam_toolbox', executable='async_slam_toolbox_node', name='slam_toolbox', output='screen', parameters=[{
            'use_sim_time': True, 'odom_frame': 'odom', 'base_frame': 'base_link', 'scan_topic': '/scan', 'map_frame': 'map',
            'max_laser_range': ParameterValue(LaunchConfiguration('range'), value_type=float),
            'resolution': ParameterValue(LaunchConfiguration('res'), value_type=float),
            'transform_publish_period': ParameterValue(LaunchConfiguration('tpp'), value_type=float),
            'stack_size_to_use': 40000000, 'transform_timeout': 0.5}])
    ])
