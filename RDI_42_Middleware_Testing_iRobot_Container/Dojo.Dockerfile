# Use the official ROS 2 Jazzy base image
FROM ros:jazzy-ros-base

# Set the working directory inside the container
WORKDIR /robot_lab

# Install system utilities, middleware binaries, and PDF reporting tools
RUN apt-get update && apt-get install -y \
    stress-ng \
    bc \
    python3-pip \
    python3-reportlab \
    python3-pandas \
    python3-matplotlib \
    python3-numpy \
    python3-scipy \
    build-essential \
    python3-colcon-common-extensions \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-rmw-zenoh-cpp \
    && rm -rf /var/lib/apt/lists/*

# Set the default middleware implementation
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# Automatically source ROS 2 when a new terminal opens
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc

CMD ["bash"]
