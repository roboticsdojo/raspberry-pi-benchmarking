#!/usr/bin/env python3
"""
Convert a CARMEN-format .log file (FLASER lines) into a ROS2 bag with
/scan (LaserScan), /odom (Odometry), /tf, and /tf_static.
Usage: python3 carmen_to_bag2.py <input.log> <output_bag_dir>

The laser has 1 degree angular resolution, so the field of view is
(N-1) x 1 degree, centred on the robot's forward axis (N=180 -> 179 deg, the
SICK LMS200 setup used for this dataset). The laser is assumed mounted at the
robot centre.
"""
import sys
import math
import numpy as np
from rosbags.rosbag2 import Writer
from rosbags.typesys import Stores, get_typestore

ANGLE_INCREMENT = math.radians(1.0)  # 1-degree resolution assumption


def yaw_to_quat(theta):
    return (0.0, 0.0, math.sin(theta / 2.0), math.cos(theta / 2.0))


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 carmen_to_bag2.py <input.log> <output_bag_dir>")
        sys.exit(1)

    src, dst = sys.argv[1], sys.argv[2]
    typestore = get_typestore(Stores.ROS2_JAZZY)

    LaserScan = typestore.types['sensor_msgs/msg/LaserScan']
    Odometry = typestore.types['nav_msgs/msg/Odometry']
    TFMessage = typestore.types['tf2_msgs/msg/TFMessage']
    TransformStamped = typestore.types['geometry_msgs/msg/TransformStamped']
    Header = typestore.types['std_msgs/msg/Header']
    Time = typestore.types['builtin_interfaces/msg/Time']
    Pose = typestore.types['geometry_msgs/msg/Pose']
    Point = typestore.types['geometry_msgs/msg/Point']
    Quaternion = typestore.types['geometry_msgs/msg/Quaternion']
    Twist = typestore.types['geometry_msgs/msg/Twist']
    Vector3 = typestore.types['geometry_msgs/msg/Vector3']
    PoseWithCovariance = typestore.types['geometry_msgs/msg/PoseWithCovariance']
    TwistWithCovariance = typestore.types['geometry_msgs/msg/TwistWithCovariance']
    Transform = typestore.types['geometry_msgs/msg/Transform']

    def stamp(t):
        sec = int(t)
        nsec = int((t - sec) * 1e9)
        return Time(sec=sec, nanosec=nsec)

    ZERO_COV = np.zeros(36, dtype=np.float64)
    EMPTY_INTENSITIES = np.array([], dtype=np.float32)

    n_scans = 0
    first_n_readings = None

    with Writer(dst, version=9) as writer:
        conn_scan = writer.add_connection('/scan', LaserScan.__msgtype__, typestore=typestore)
        conn_odom = writer.add_connection('/odom', Odometry.__msgtype__, typestore=typestore)
        conn_tf = writer.add_connection('/tf', TFMessage.__msgtype__, typestore=typestore)
        conn_tf_static = writer.add_connection('/tf_static', TFMessage.__msgtype__, typestore=typestore)

        static_written = False

        with open(src, 'r') as f:
            for line in f:
                if not line.startswith('FLASER'):
                    continue
                parts = line.split()
                n = int(parts[1])
                if first_n_readings is None:
                    first_n_readings = n
                ranges = np.array(parts[2:2 + n], dtype=np.float32)
                idx = 2 + n
                odom_x = float(parts[idx + 3])
                odom_y = float(parts[idx + 4])
                odom_theta = float(parts[idx + 5])
                t = float(parts[idx + 6])
                ts = stamp(t)
                t_ns = int(t * 1e9)

                angle_max = ANGLE_INCREMENT * (n - 1) / 2.0
                angle_min = -angle_max

                scan_msg = LaserScan(
                    header=Header(stamp=ts, frame_id='base_laser_link'),
                    angle_min=angle_min,
                    angle_max=angle_max,
                    angle_increment=ANGLE_INCREMENT,
                    time_increment=0.0,
                    scan_time=0.0,
                    range_min=0.05,
                    range_max=81.0,
                    ranges=ranges,
                    intensities=EMPTY_INTENSITIES,
                )
                writer.write(conn_scan, t_ns, typestore.serialize_cdr(scan_msg, LaserScan.__msgtype__))

                qx, qy, qz, qw = yaw_to_quat(odom_theta)
                odom_msg = Odometry(
                    header=Header(stamp=ts, frame_id='odom'),
                    child_frame_id='base_link',
                    pose=PoseWithCovariance(
                        pose=Pose(
                            position=Point(x=odom_x, y=odom_y, z=0.0),
                            orientation=Quaternion(x=qx, y=qy, z=qz, w=qw),
                        ),
                        covariance=ZERO_COV,
                    ),
                    twist=TwistWithCovariance(
                        twist=Twist(linear=Vector3(x=0.0, y=0.0, z=0.0), angular=Vector3(x=0.0, y=0.0, z=0.0)),
                        covariance=ZERO_COV,
                    ),
                )
                writer.write(conn_odom, t_ns, typestore.serialize_cdr(odom_msg, Odometry.__msgtype__))

                tf_odom = TransformStamped(
                    header=Header(stamp=ts, frame_id='odom'),
                    child_frame_id='base_link',
                    transform=Transform(
                        translation=Vector3(x=odom_x, y=odom_y, z=0.0),
                        rotation=Quaternion(x=qx, y=qy, z=qz, w=qw),
                    ),
                )
                tf_msg = TFMessage(transforms=[tf_odom])
                writer.write(conn_tf, t_ns, typestore.serialize_cdr(tf_msg, TFMessage.__msgtype__))

                if not static_written:
                    tf_static = TransformStamped(
                        header=Header(stamp=ts, frame_id='base_link'),
                        child_frame_id='base_laser_link',
                        transform=Transform(
                            translation=Vector3(x=0.0, y=0.0, z=0.0),
                            rotation=Quaternion(x=0.0, y=0.0, z=0.0, w=1.0),
                        ),
                    )
                    tf_static_msg = TFMessage(transforms=[tf_static])
                    writer.write(conn_tf_static, t_ns, typestore.serialize_cdr(tf_static_msg, TFMessage.__msgtype__))
                    static_written = True

                n_scans += 1

    print(f"Done. Wrote {n_scans} scans. First FLASER reading count: {first_n_readings}")


if __name__ == '__main__':
    main()
