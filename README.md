# 龟龟温度计（edx）

基于 Flutter 的多端（Android/iOS/桌面/Web）温度监控与可视化应用，支持通过 MQTT 实时接收多传感器温度数据，历史曲线可交互分析，适用于物联网、环境监测等场景。

## 主要功能
- **多传感器温度实时监控**：通过 MQTT 协议接收多设备温度数据，自动区分设备。
- **历史温度曲线可视化**：支持多设备温度历史曲线，内置多种数据点形状和颜色区分。
- **交互式数据分析**：支持点击/滑动横坐标，显示该时刻所有传感器温度（Syncfusion Trackball）。
- **本地配置持久化**：MQTT 服务器、主题、Y轴范围等参数本地保存。
- **自定义背景与美观UI**：支持自定义背景图片，界面美观，适合大屏展示。
- **MQTT测试发送**：可在设置页直接向主题发送测试消息。

## 截图示例
> 建议在此处插入应用主界面和设置界面截图。

## 依赖环境
- Flutter 3.8.1 及以上
- 主要依赖：
  - mqtt_client ^10.0.0
  - sqflite ^2.3.3
  - path ^1.9.0
  - syncfusion_flutter_charts ^29.2.11

## 目录结构
```
lib/
  main.dart           # 主程序入口，包含UI与业务逻辑
assets/
  backe.png           # 背景图片
  icons/              # 各平台图标资源
    android/          # Android图标
    ios/              # iOS图标
...
README.md             # 项目说明文档
pubspec.yaml          # 依赖与资源声明
```

## 安装与运行
1. **准备Flutter环境**（建议3.8.1及以上）
2. **获取依赖**
   ```bash
   flutter pub get
   ```
3. **运行项目**
   - Android/iOS：
     ```bash
     flutter run
     ```
   - Web：
     ```bash
     flutter run -d chrome
     ```
   - 桌面（macOS/Windows/Linux）：
     ```bash
     flutter run -d macos  # 或 windows/linux
     ```

## 配置说明
- **MQTT参数**：在"设置"页填写服务器地址、端口、Client ID、用户名、密码、主题、是否SSL。
- **Y轴设置**：可自定义温度曲线的最小值、最大值、间隔。
- **数据格式**：后端需推送如下JSON格式：
  ```json
  {
    "dev1": {"l_t": [23.1, 23.2, ...], "c_t": 23.2},
    "dev2": {"l_t": [21.8, 21.9, ...], "c_t": 21.9}
  }
  ```
  - `l_t`为历史温度数组，`c_t`为当前温度。

## 代码规范
- 遵循 [flutter_lints](https://pub.dev/packages/flutter_lints) 规范。

## 致谢
- [Syncfusion Flutter Charts](https://pub.dev/packages/syncfusion_flutter_charts) 提供强大的数据可视化能力。
- [mqtt_client](https://pub.dev/packages/mqtt_client) 实现MQTT通信。

---
如有问题或建议，欢迎提 issue 或 PR。
