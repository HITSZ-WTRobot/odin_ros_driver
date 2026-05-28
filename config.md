# `config/control_command.yaml` 配置说明

本文档说明 Odin ROS Driver 的控制配置文件：

```text
config/control_command.yaml
```

该文件用于控制驱动连接策略、时间戳策略、传感器数据流、ROS topic 发布、主机端后处理、录制日志，以及 Odin 设备的 odometry / SLAM / relocalization 模式。

## 基本结构

配置文件的所有参数都放在 `register_keys` 下：

```yaml
register_keys:
  sendrgb: 1
  sendimu: 1
  custom_map_mode: 0
```

大部分字段使用整数开关：

| 值 | 含义 |
|---:|---|
| `0` | 关闭 |
| `1` | 开启 |

少数字段使用字符串，例如地图路径和保存路径。

## 解析规则

驱动启动时会读取 `control_command.yaml`。主节点 `host_sdk_sample` 会读取该配置；深度补全节点和点云重投影节点也会读取其中对应的开关。

解析规则如下：

| 参数类型 | 规则 |
|---|---|
| 普通整数参数 | 直接作为 `int` 读取，例如 `sendrgb: 1` |
| 字符串参数 | 目前包括 `relocalization_map_abs_path`、`mapping_result_dest_dir`、`mapping_result_file_name` |
| `custom_` 前缀参数 | 去掉 `custom_` 前缀后作为设备自定义参数下发 |

例如：

| YAML 字段 | 实际设备参数名 |
|---|---|
| `custom_map_mode` | `map_mode` |
| `custom_init_pos` | `init_pos` |

因此，`custom_map_mode: 1` 会向设备下发 `map_mode = 1`。

修改 YAML 后通常需要重新启动 launch / 节点才能生效。例外是 `save_map` 这类运行时命令，它不是通过修改 YAML 触发，而是通过 `set_param.sh` 下发。

## 当前配置概览

当前 `control_command.yaml` 的主要行为是：

| 功能 | 当前状态 |
|---|---|
| USB 3.0 严格检查 | 关闭 |
| 时间戳模式 | Odin 时间对齐到主机 ROS 时间轴 |
| RGB 压缩图 | 开启 |
| RGB 解码图 | 开启 |
| RGB 去畸变图 | 开启 |
| IMU | 开启 |
| Odometry | 开启 |
| `odom -> odin1_base_link` TF | 开启 |
| 原始 DTOF 点云 | 开启 |
| DTOF 帧率 | 10 fps |
| SLAM 点云 | 开启 |
| 彩色渲染点云 | 开启 |
| 深度补全 demo | 开启 |
| 点云重投影 demo | 开启 |
| 原始数据录制 | 关闭 |
| 设备状态日志 | 开启 |
| 驱动日志保存 | 关闭 |
| intensity 灰度调试图 | 关闭 |
| path 显示 | 关闭 |
| camera pose 显示 | 关闭 |
| 地图模式 | Odometry mode |

## 参数明细

### 连接与时间

| 参数 | 当前值 | 取值 | 说明 |
|---|---:|---|---|
| `strict_usb3.0_check` | `0` | `0` / `1` | 是否强制要求 USB 3.0 连接。关闭后，低于 USB 3.0 的连接也允许启动。SLAM、地图传输等高带宽功能仍建议使用 USB 3.0。 |
| `use_host_ros_time` | `2` | `0` / `1` / `2` | ROS 消息时间戳策略。 |

`use_host_ros_time` 的取值含义：

| 值 | 含义 | 适用场景 |
|---:|---|---|
| `0` | 使用 Odin 设备内部时间作为数据时间戳 | 官方注释中推荐的典型模式 |
| `1` | 使用主机 ROS 收到数据时的时间 | 仅在明确需要主机接收时间时使用，通常不推荐 |
| `2` | 将 Odin 时间对齐到主机时间轴 | 需要让传感器时间戳落在主机 ROS 时间轴时使用 |

### 数据流总开关

| 参数 | 当前值 | 取值 | 说明 |
|---|---:|---|---|
| `streamctrl` | `1` | `0` / `1` | 数据流总开关。`1` 表示启动数据流，`0` 表示关闭数据流。 |

### RGB 图像

| 参数 | 当前值 | 对应 topic | 说明 |
|---|---:|---|---|
| `sendrgbcompressed` | `1` | `/odin1/image/compressed` | 发布设备原始 JPEG 压缩 RGB 图像。 |
| `sendrgb` | `1` | `/odin1/image` | 发布主机端解码后的 RGB 图像，格式为 `bgr8`。 |
| `sendrgbundistort` | `1` | `/odin1/image_undistort` | 发布去畸变后的 RGB 图像，依赖 `sendrgb`，使用 `config/calib.yaml` 中的相机标定参数。 |

说明：

- `sendrgbcompressed` 是设备传来的原始 JPEG 数据，带宽相对较低。
- `sendrgb` 会在主机端解码 JPEG。
- `sendrgbundistort` 会在主机端进行去畸变处理，计算量高于普通 RGB 发布。

### IMU 与里程计

| 参数 | 当前值 | 对应 topic / TF | 说明 |
|---|---:|---|---|
| `sendimu` | `1` | `/odin1/imu` | 发布 IMU 数据。 |
| `sendodom` | `1` | `/odin1/odometry`、`/odin1/odometry_high` | 发布里程计数据。 |
| `send_odom_baselink_tf` | `1` | `odom -> odin1_base_link` | 发布里程计坐标系到机体坐标系的 TF。 |

建议保持 `send_odom_baselink_tf: 1`。`/odin1/cloud_raw` 的坐标系是 `odin1_base_link`，RViz 或其他节点通常需要 `odom -> odin1_base_link` TF 才能把原始点云变换到 `odom` 下显示或处理。

### DTOF 原始点云

| 参数 | 当前值 | 对应 topic | 说明 |
|---|---:|---|---|
| `senddtof` | `1` | `/odin1/cloud_raw` | 发布原始 DTOF 点云。 |
| `cloud_raw_confidence_threshold` | `35` | `/odin1/cloud_raw` | 原始点云置信度过滤阈值。 |
| `dtof_fps` | `100` | `/odin1/cloud_raw` | DTOF 传感器帧率设置。 |

`/odin1/cloud_raw` 的点云字段：

| 字段 | 类型 | 含义 |
|---|---|---|
| `x` | `float32` | X 坐标，单位 m |
| `y` | `float32` | Y 坐标，单位 m |
| `z` | `float32` | Z 坐标，单位 m |
| `intensity` | `uint8` | 反射强度 |
| `confidence` | `uint16` | 点置信度，值越高越可靠 |
| `offset_time` | `float32` | 相对基准时间戳的偏移，单位 s |

`cloud_raw_confidence_threshold` 会过滤低置信度点。当前阈值是 `35`。如果某个点的 `confidence` 小于该阈值，驱动会将该点的数据置为 0。

`dtof_fps` 支持值：

| 值 | 实际帧率 |
|---:|---:|
| `100` | 10 fps |
| `145` | 14.5 fps |

较高帧率会使点云更平滑，但会增加带宽和处理压力。若设置为不支持的值，代码会回退到默认帧率。

### SLAM 点云与彩色点云

| 参数 | 当前值 | 对应 topic | 说明 |
|---|---:|---|---|
| `sendcloudslam` | `1` | `/odin1/cloud_slam` | 发布 SLAM 点云。 |
| `sendcloudrender` | `1` | `/odin1/cloud_render` | 发布由原始点云、RGB 图像和相机标定处理得到的彩色渲染点云。 |

坐标系说明：

| Topic | `frame_id` | 坐标含义 |
|---|---|---|
| `/odin1/cloud_raw` | `odin1_base_link` | 原始 DTOF 点云，在设备 / 机体当前坐标系下 |
| `/odin1/cloud_slam` | `odom` | SLAM / 里程计点云，在 `odom` 坐标系下 |
| `/odin1/cloud_render` | `odin1_base_link` | 主机端渲染得到的彩色点云，在设备 / 机体当前坐标系下 |

如果需要比较 `/odin1/cloud_raw` 和 `/odin1/cloud_slam`，应通过 TF 将 `/odin1/cloud_raw` 从 `odin1_base_link` 变换到 `odom`。

### 深度补全与重投影

| 参数 | 当前值 | 对应 topic | 说明 |
|---|---:|---|---|
| `senddepth` | `1` | `/odin1/depth_img_competetion`、`/odin1/depth_img_competetion_cloud` | 开启深度补全 demo。计算资源占用较高。 |
| `sendreprojection` | `1` | `/odin1/reprojected_image` | 开启点云重投影 demo，将 `cloud_slam` 根据 odometry 投影到相机图像。 |

说明：

- `senddepth` 由深度补全节点读取。
- `sendreprojection` 由点云重投影节点读取。
- 如果只需要基础定位和点云显示，可以关闭这两个参数以降低 CPU / GPU 压力。

### 录制与日志

| 参数 | 当前值 | 说明 |
|---|---:|---|
| `recorddata` | `0` | 是否录制 RGB、odometry、SLAM cloud 等数据为 MindCloud(TM) 后处理格式。 |
| `devstatuslog` | `1` | 是否保存设备运行状态日志。 |
| `save_log` | `0` | 是否保存驱动日志。 |

`recorddata` 会消耗大量磁盘空间。README 中给出的参考数据约为 10 分钟 9.5 GB。仅在需要后处理或复现实验时开启。

`devstatuslog` 会保存设备状态，例如 SoC 温度、CPU 使用率、RAM 使用率、DTOF 传感器温度、数据收发速率等。路径类似：

```text
log/Driver_{driver_start_time}/Conn_{device_connection_time}/dev_status.csv
```

### 调试与显示

| 参数 | 当前值 | 对应 topic / 功能 | 说明 |
|---|---:|---|---|
| `pubintensitygray` | `0` | intensity 灰度图 | 发布原始 DTOF intensity 灰度图，主要用于调试。 |
| `showpath` | `0` | `/odin1/path` | 发布 / 显示 odometry path。 |
| `showcamerapose` | `0` | camera pose / FOV | 显示相机位姿和视场。 |

### 地图、SLAM 与重定位

| 参数 | 当前值 | 类型 | 说明 |
|---|---:|---|---|
| `custom_map_mode` | `0` | `int` | 运行模式。该字段会作为设备参数 `map_mode` 下发。 |
| `custom_init_pos` | `[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]` | float array | 初始化位姿。该字段会作为设备参数 `init_pos` 下发。README 标注为 currently unused。 |
| `relocalization_map_abs_path` | `/home/rediducky/catkin_ws/src/odin_ros_driver/map/20260508_203631/test_right_01.bin` | string | 重定位模式下使用的已有地图文件绝对路径。 |
| `mapping_result_dest_dir` | `""` | string | SLAM 建图模式下保存地图的目标目录。空字符串表示使用默认路径。 |
| `mapping_result_file_name` | `""` | string | SLAM 建图模式下保存地图的文件名。空字符串表示使用默认文件名。 |

`custom_map_mode` 的取值：

| 值 | 模式 | 是否需要已有地图 | 说明 |
|---:|---|---|---|
| `0` | Odometry mode | 不需要 | 普通里程计模式。短时间局部位姿连续，但长时间会累积漂移。 |
| `1` | SLAM / Mapping mode | 不需要 | 在线建图模式，在 odometry 基础上增加回环检测和地图保存能力。 |
| `2` | Relocalization mode | 需要 | 加载已有地图并进行重定位。需要设置有效的 `relocalization_map_abs_path`。 |

#### Odometry mode

```yaml
custom_map_mode: 0
```

该模式下，系统输出 odometry 结果。没有已有地图，也不进行地图保存。适合短时间运行、局部定位、实时控制和基础点云显示。

#### SLAM / Mapping mode

```yaml
custom_map_mode: 1
```

该模式下，系统会在线建图，并支持回环检测和地图保存。没有回环时，短时间实时轨迹通常与 odometry 模式接近；经过已访问区域并触发回环后，可以修正累计漂移，提高全局一致性。

保存地图时，在驱动源码目录执行：

```bash
./set_param.sh save_map 1
```

如果未设置保存路径和文件名，默认保存到：

```text
map/{driver_start_time}/map_{map_save_time}.bin
```

如果需要指定保存位置：

```yaml
mapping_result_dest_dir: "/absolute/path/to/map_dir"
mapping_result_file_name: "my_map.bin"
```

#### Relocalization mode

```yaml
custom_map_mode: 2
relocalization_map_abs_path: "/absolute/path/to/map.bin"
```

该模式需要已有地图。驱动启动后会加载 `relocalization_map_abs_path` 指向的地图文件，并尝试在该地图中重定位。

注意：

- `relocalization_map_abs_path` 必须是有效的绝对路径。
- 如果路径为空、文件不存在或设备加载失败，驱动会报错并关闭设备连接。
- 当前配置中的路径指向 `/home/rediducky/...`，如果在当前机器上使用重定位模式，通常需要改成实际存在的地图路径。

## 常用配置建议

### 基础定位和 RViz 看点云

适合先确认设备和驱动是否正常：

```yaml
sendimu: 1
sendodom: 1
send_odom_baselink_tf: 1
senddtof: 1
sendcloudslam: 1
sendrgb: 1
senddepth: 0
sendreprojection: 0
custom_map_mode: 0
```

### 降低主机计算压力

可优先关闭主机端处理开销较大的功能：

```yaml
sendrgbundistort: 0
sendcloudrender: 0
senddepth: 0
sendreprojection: 0
pubintensitygray: 0
```

### 建图并保存地图

```yaml
custom_map_mode: 1
sendcloudslam: 1
sendodom: 1
```

建图完成后执行：

```bash
./set_param.sh save_map 1
```

### 使用已有地图重定位

```yaml
custom_map_mode: 2
relocalization_map_abs_path: "/absolute/path/to/map.bin"
```

重定位模式下建议从建图轨迹附近启动。README 建议启动位置尽量在原始 SLAM 轨迹的 1 m、10 deg 范围内，以提高首次重定位成功率。

## Topic 对照表

| Topic | 配置项 | 坐标系 | 说明 |
|---|---|---|---|
| `/odin1/imu` | `sendimu` | `imu_link` | IMU 数据 |
| `/odin1/image` | `sendrgb` | 未显式设置 | 解码后的 RGB 图像，`bgr8` |
| `/odin1/image_undistort` | `sendrgbundistort` | 未显式设置 | 去畸变 RGB 图像 |
| `/odin1/image/compressed` | `sendrgbcompressed` | 未显式设置 | 原始 JPEG 压缩图像 |
| `/odin1/cloud_raw` | `senddtof` | `odin1_base_link` | 原始 DTOF 点云 |
| `/odin1/cloud_render` | `sendcloudrender` | `odin1_base_link` | 主机端生成的彩色渲染点云 |
| `/odin1/cloud_slam` | `sendcloudslam` | `odom` | SLAM 点云 |
| `/odin1/odometry` | `sendodom` | `odom -> odin1_base_link` | 标准 odometry |
| `/odin1/odometry_high` | `sendodom` | `odom -> odin1_base_link` | 高频 odometry |
| `/odin1/path` | `showpath` | `odom` | 轨迹 path |
| `/odin1/depth_img_competetion` | `senddepth` | 与深度节点实现相关 | 深度补全图像 |
| `/odin1/depth_img_competetion_cloud` | `senddepth` | 与深度节点实现相关 | 深度补全点云 |
| `/odin1/reprojected_image` | `sendreprojection` | 图像坐标 | `cloud_slam` 重投影结果 |

## 注意事项

- `/odin1/cloud_raw` 和 `/odin1/cloud_slam` 不在同一坐标系下。前者是 `odin1_base_link`，后者是 `odom`。
- 需要比较两者时，应使用 TF 将 `/odin1/cloud_raw` 变换到 `odom`。
- `send_odom_baselink_tf` 建议保持开启，否则 RViz 和下游节点可能无法正确显示 / 使用原始点云。
- `custom_map_mode: 1` 不需要已有地图，它会在线建图。
- `custom_map_mode: 2` 必须提供已有地图文件。
- `recorddata` 会快速占用磁盘空间，默认关闭是合理的。
- 修改配置后重新启动节点，确保配置被重新读取。
