# Build context = third_party/ros2-performance (see build_image.sh).
# Keeping this file out of the upstream repo keeps that repo a pure C++ framework.
FROM ros:jazzy-ros-base

# Uncomment to force apt to use IPv4 ONLY if you run into connection issues
#RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# 1. Install dependencies and RMW implementations
RUN rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get update \
    && apt-get install -y \
        software-properties-common \
    && add-apt-repository universe \
    && apt-get update \
    && apt-get install -y \
        ros-jazzy-rmw-fastrtps-cpp \
        ros-jazzy-rmw-cyclonedds-cpp \
        ros-jazzy-rmw-zenoh-cpp \
        python3-pip \
        git \
        nlohmann-json3-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Set up workspace and copy sources
WORKDIR /benchmark_ws/src
COPY . /benchmark_ws/src/ros2-performance

# 3. Apply the COLCON_IGNOREs to non-essential packages
RUN touch /benchmark_ws/src/ros2-performance/memory_benchmark/COLCON_IGNORE 2>/dev/null || true \
    && touch /benchmark_ws/src/ros2-performance/composition_benchmark/COLCON_IGNORE 2>/dev/null || true \
    && touch /benchmark_ws/src/ros2-performance/performance_test_examples/COLCON_IGNORE 2>/dev/null || true

# 4. Automatically source setup scripts (prep work)
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc \
    && echo "source /benchmark_ws/install/setup.bash" >> ~/.bashrc

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
