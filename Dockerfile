# syntax=docker/dockerfile:1.7

ARG ROS_DISTRO=humble
FROM ros:${ROS_DISTRO}-ros-base

ARG ROS_DISTRO=humble
ARG UBUNTU_MIRROR=https://mirror.nju.edu.cn/ubuntu/
ARG ROS2_APT_MIRROR=https://mirrors.nju.edu.cn/ros2/ubuntu

ENV ROS_DISTRO=${ROS_DISTRO} \
    WORKSPACE_DIR=/workspace \
    ODIN_ROS_DRIVER_DIR=/workspace/src/odin_ros_driver \
    DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN <<EOF
set -euo pipefail
rm -f /etc/apt/sources.list.d/ubuntu.sources
cat >/etc/apt/sources.list <<SOURCES
# Source mirror entries are commented out to keep apt update fast.
deb ${UBUNTU_MIRROR} jammy main restricted universe multiverse
# deb-src ${UBUNTU_MIRROR} jammy main restricted universe multiverse
deb ${UBUNTU_MIRROR} jammy-updates main restricted universe multiverse
# deb-src ${UBUNTU_MIRROR} jammy-updates main restricted universe multiverse
deb ${UBUNTU_MIRROR} jammy-backports main restricted universe multiverse
# deb-src ${UBUNTU_MIRROR} jammy-backports main restricted universe multiverse

# deb ${UBUNTU_MIRROR} jammy-security main restricted universe multiverse
# deb-src ${UBUNTU_MIRROR} jammy-security main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

# Prerelease repository, not recommended.
# deb ${UBUNTU_MIRROR} jammy-proposed main restricted universe multiverse
# deb-src ${UBUNTU_MIRROR} jammy-proposed main restricted universe multiverse
SOURCES
for ros_source in \
    /etc/apt/sources.list.d/ros2.sources \
    /etc/apt/sources.list.d/ros2.list \
    /etc/apt/sources.list.d/ros2-latest.list \
    /usr/share/ros-apt-source/ros2.sources; do
    if [ -e "${ros_source}" ] || [ -L "${ros_source}" ]; then
        sed -i --follow-symlinks \
            -e "s#http://packages.ros.org/ros2/ubuntu#${ROS2_APT_MIRROR}#g" \
            -e "s#https://packages.ros.org/ros2/ubuntu#${ROS2_APT_MIRROR}#g" \
            -e "s#^Types: deb deb-src\$#Types: deb#g" \
            "${ros_source}"
    fi
done
EOF

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libeigen3-dev \
        libopencv-dev \
        libpcl-dev \
        procps \
        libssl-dev \
        libusb-1.0-0-dev \
        libyaml-cpp-dev \
        pkg-config \
        python3-colcon-common-extensions \
        python3-yaml \
        ros-${ROS_DISTRO}-ament-cmake \
        ros-${ROS_DISTRO}-ament-index-cpp \
        ros-${ROS_DISTRO}-cv-bridge \
        ros-${ROS_DISTRO}-geometry-msgs \
        ros-${ROS_DISTRO}-image-transport \
        ros-${ROS_DISTRO}-launch \
        ros-${ROS_DISTRO}-launch-ros \
        ros-${ROS_DISTRO}-message-filters \
        ros-${ROS_DISTRO}-nav-msgs \
        ros-${ROS_DISTRO}-pcl-conversions \
        ros-${ROS_DISTRO}-rclcpp \
        ros-${ROS_DISTRO}-rviz2 \
        ros-${ROS_DISTRO}-sensor-msgs \
        ros-${ROS_DISTRO}-std-msgs \
        ros-${ROS_DISTRO}-tf2 \
        ros-${ROS_DISTRO}-tf2-geometry-msgs \
        ros-${ROS_DISTRO}-tf2-ros \
        ros-${ROS_DISTRO}-visualization-msgs \
        usbutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${WORKSPACE_DIR}

COPY CMakeLists.txt package.xml README.md src/odin_ros_driver/
COPY include/ src/odin_ros_driver/include/
COPY launch_ROS2/ src/odin_ros_driver/launch_ROS2/
COPY lib/ src/odin_ros_driver/lib/
COPY script/ src/odin_ros_driver/script/
COPY src/ src/odin_ros_driver/src/
COPY set_param.sh src/odin_ros_driver/

RUN source "/opt/ros/${ROS_DISTRO}/setup.bash" \
    && colcon build \
        --packages-select odin_ros_driver \
        --cmake-args \
            -DBUILD_SYSTEM=ROS2 \
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    && test -x "${WORKSPACE_DIR}/install/odin_ros_driver/lib/odin_ros_driver/host_sdk_sample" \
    && test -x "${WORKSPACE_DIR}/install/odin_ros_driver/lib/odin_ros_driver/pcd2depth_ros2_node" \
    && test -x "${WORKSPACE_DIR}/install/odin_ros_driver/lib/odin_ros_driver/cloud_reprojection_ros2_node"

RUN mkdir -p "${ODIN_ROS_DRIVER_DIR}/config" "${ODIN_ROS_DRIVER_DIR}/map" \
    && rm -rf "${WORKSPACE_DIR}/install/odin_ros_driver/share/odin_ros_driver/config" \
    && ln -s "${ODIN_ROS_DRIVER_DIR}/config" "${WORKSPACE_DIR}/install/odin_ros_driver/share/odin_ros_driver/config"

VOLUME ["/workspace/src/odin_ros_driver/config", "/workspace/src/odin_ros_driver/map"]

COPY --chmod=755 docker/ros_entrypoint.sh /ros_entrypoint.sh

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "launch", "odin_ros_driver", "odin1_ros2.launch.py", "use_rviz:=false"]
