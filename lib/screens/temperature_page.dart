import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/temperature_data.dart';
import '../services/mqtt_service.dart';
import '../services/mqtt_storage.dart';
import '../widgets/triangle_painter.dart';

class TemperaturePage extends StatefulWidget {
  const TemperaturePage({super.key});

  @override
  State<TemperaturePage> createState() => _TemperaturePageState();
}

class _TemperaturePageState extends State<TemperaturePage> {
  final mqtt = MqttService();
  Stream<List<MqttReceivedMessage<MqttMessage>>>? _mqttStream;
  Timer? _refreshTimer;

  final TrackballBehavior _trackballBehavior = TrackballBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    tooltipSettings: const InteractiveTooltip(enable: true),
    shouldAlwaysShow: false,
    lineType: TrackballLineType.vertical,
    markerSettings: const TrackballMarkerSettings(
      markerVisibility: TrackballVisibilityMode.visible,
    ),
    tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
  );

  @override
  void initState() {
    super.initState();
    _tryConnectMqtt();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConfigValid() && mqtt.isConnected) {
        _sendRefresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryConnectMqtt() async {
    await MqttConfigStorage().loadConfig(mqtt);
    if (_isConfigValid() && !mqtt.isConnected) {
      await mqtt.connect();
    }
    if (_isConfigValid() && mqtt.isConnected) {
      _subscribeAndListen();
      _sendRefresh();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _subscribeAndListen() {
    mqtt.client.subscribe(mqtt.topic, MqttQos.atLeastOnce);
    _mqttStream = mqtt.client.updates;
    _mqttStream?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      if (mounted) {
        setState(() {
          mqtt.updateTemperatureData(pt);
        });
      }
    });
  }

  bool _isConfigValid() {
    return mqtt.host.isNotEmpty &&
        mqtt.port > 0 &&
        mqtt.clientId.isNotEmpty &&
        mqtt.topic.isNotEmpty;
  }

  void _sendRefresh() {
    if (!mqtt.isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString('refresh');
    mqtt.client.publishMessage(
      mqtt.topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildLegendShape(int idx) {
    final color = _getRandomColor(idx);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildChart() {
    if (mqtt.deviceHistory.isEmpty) {
      return const Center(child: Text('暂无温度数据'));
    }
    final ymin = mqtt.ymin;
    final ymax = mqtt.ymax;
    final interval = mqtt.yinterval;
    List<ChartSeries> series = [];
    mqtt.deviceHistory.entries.toList().asMap().entries.forEach((entry) {
      final idx = entry.key;
      final dev = entry.value.key;
      final data = entry.value.value;
      List<TemperatureData> temperatureData = [];
      for (int i = 0; i < data.length; i++) {
        temperatureData.add(TemperatureData(i.toDouble(), data[i], dev));
      }
      final color = _getRandomColor(idx);
      const markerSettings = MarkerSettings(isVisible: false);
      series.add(
        LineSeries<TemperatureData, double>(
          dataSource: temperatureData,
          xValueMapper: (TemperatureData data, _) => data.x,
          yValueMapper: (TemperatureData data, _) => data.y,
          name: dev,
          color: color,
          markerSettings: markerSettings,
        ),
      );
    });
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (outerContext, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Center(
                child: Transform.rotate(
                  angle: 1.5708,
                  child: SizedBox(
                    width: height,
                    height: width,
                    child: Image.asset('assets/backe.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              RotatedBox(
                quarterTurns: 1,
                child: SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    isVisible: true,
                    labelStyle: const TextStyle(color: Colors.transparent),
                    majorTickLines: const MajorTickLines(size: 0),
                    majorGridLines: MajorGridLines(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                    axisLine: AxisLine(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  primaryYAxis: NumericAxis(
                    // Removed Y-axis title '温度'
                    minimum: ymin,
                    maximum: ymax,
                    interval: interval,
                    majorTickLines: const MajorTickLines(size: 0),
                    majorGridLines: MajorGridLines(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                    axisLine: AxisLine(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  series: series.cast<CartesianSeries>(),
                  legend: const Legend(isVisible: false),
                  trackballBehavior: _trackballBehavior,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getRandomColor(int idx) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.cyan,
      Colors.pink,
      Colors.indigo,
      Colors.teal,
      Colors.amber,
      Colors.deepPurple,
      Colors.lightBlue,
      Colors.lime,
      Colors.deepOrange,
      Colors.blueGrey,
    ];
    return colors[idx % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ShadResizablePanelGroup(
          axis: Axis.vertical,
          showHandle: true,
          dividerThickness: 1,
          children: [
            ShadResizablePanel(
              id: 'top',
              defaultSize: 0.4,
              minSize: 0.4,
              maxSize: 0.65,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: mqtt.deviceCurrent.isNotEmpty
                    ? RotatedBox(
                        quarterTurns: 1,
                        child: ShadCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: mqtt.deviceCurrent.entries
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                                  final idx = entry.key;
                                  final dev = entry.value.key;
                                  final tempList =
                                      mqtt.deviceHistory[dev] ?? [];
                                  final current =
                                      mqtt.deviceCurrent[dev] ?? 0.0;
                                  final max = tempList.isNotEmpty
                                      ? tempList.reduce((a, b) => a > b ? a : b)
                                      : 0.0;
                                  final min = tempList.isNotEmpty
                                      ? tempList.reduce((a, b) => a < b ? a : b)
                                      : 0.0;
                                  final avg = tempList.isNotEmpty
                                      ? (tempList.reduce((a, b) => a + b) /
                                            tempList.length)
                                      : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildLegendShape(idx),
                                            const SizedBox(width: 8),
                                            Text(
                                              dev,
                                              style: theme.textTheme.h4,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Text(
                                              current.toStringAsFixed(1),
                                              style: theme.textTheme.large
                                                  .copyWith(
                                                    color: Colors.green,
                                                  ),
                                            ),
                                            const SizedBox(width: 24),
                                            Text(
                                              max.toStringAsFixed(1),
                                              style: theme.textTheme.large
                                                  .copyWith(color: Colors.red),
                                            ),
                                            const SizedBox(width: 24),
                                            Text(
                                              avg.toStringAsFixed(1),
                                              style: theme.textTheme.large
                                                  .copyWith(
                                                    color: Colors.orange,
                                                  ),
                                            ),
                                            const SizedBox(width: 24),
                                            Text(
                                              min.toStringAsFixed(1),
                                              style: theme.textTheme.large
                                                  .copyWith(color: Colors.blue),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      )
                    : Center(
                        child: Text('暂无当前数据', style: theme.textTheme.muted),
                      ),
              ),
            ),
            ShadResizablePanel(
              id: 'bottom',
              defaultSize: 0.55,
              minSize: 0.3,
              maxSize: 0.55,
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }
}
