import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

// 自定义三角形绘制器
class TrianglePainter extends CustomPainter {
  final Color color;
  
  TrianglePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MqttConfigStorage().init();
  runApp(const MainApp());
}

// MQTT配置存储
class MqttConfigStorage {
  static final MqttConfigStorage _instance = MqttConfigStorage._internal();
  factory MqttConfigStorage() => _instance;
  MqttConfigStorage._internal();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mqtt_config.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mqtt_config (
            id INTEGER PRIMARY KEY,
            host TEXT,
            port INTEGER,
            clientId TEXT,
            username TEXT,
            password TEXT,
            topic TEXT,
            useSSL INTEGER,
            ymin REAL,
            ymax REAL,
            yinterval REAL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE mqtt_config ADD COLUMN ymin REAL');
          await db.execute('ALTER TABLE mqtt_config ADD COLUMN ymax REAL');
          await db.execute('ALTER TABLE mqtt_config ADD COLUMN yinterval REAL');
        }
      },
    );
  }

  Future<void> saveConfig(MqttService mqtt) async {
    if (_db == null) return;
    await _db!.delete('mqtt_config');
    await _db!.insert('mqtt_config', {
      'host': mqtt.host,
      'port': mqtt.port,
      'clientId': mqtt.clientId,
      'username': mqtt.username,
      'password': mqtt.password,
      'topic': mqtt.topic,
      'useSSL': mqtt.useSSL ? 1 : 0,
      'ymin': mqtt.ymin,
      'ymax': mqtt.ymax,
      'yinterval': mqtt.yinterval,
    });
  }

  Future<void> loadConfig(MqttService mqtt) async {
    if (_db == null) return;
    final list = await _db!.query('mqtt_config', limit: 1);
    if (list.isNotEmpty) {
      final map = list.first;
      mqtt.host = map['host'] as String? ?? '';
      mqtt.port = map['port'] as int? ?? 1883;
      mqtt.clientId = map['clientId'] as String? ?? '';
      mqtt.username = map['username'] as String? ?? '';
      mqtt.password = map['password'] as String? ?? '';
      mqtt.topic = map['topic'] as String? ?? '';
      mqtt.useSSL = (map['useSSL'] as int? ?? 0) == 1;
      mqtt.ymin = (map['ymin'] as num?)?.toDouble() ?? -5.0;
      mqtt.ymax = (map['ymax'] as num?)?.toDouble() ?? 50.0;
      mqtt.yinterval = (map['yinterval'] as num?)?.toDouble() ?? 5.0;
    }
  }
}

// MQTT 单例服务
class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  late MqttServerClient client;
  bool isConnected = false;

  String host = '';
  int port = 1883;
  String clientId = '';
  String username = '';
  String password = '';
  String topic = '';
  bool useSSL = false;
  double ymin = -5.0;
  double ymax = 50.0;
  double yinterval = 5.0;

  // 新增：缓存温度数据
  Map<String, List<double>> deviceHistory = {};
  Map<String, double> deviceCurrent = {};

  MqttService._internal();

  // 新增：处理温度数据
  void updateTemperatureData(String payload) {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        (payload.isNotEmpty) ? (jsonDecode(payload)) : {},
      );
      final Map<String, List<double>> newHistory = {};
      final Map<String, double> newCurrent = {};
      data.forEach((dev, v) {
        if (v is Map<String, dynamic> && v['l_t'] is List && v['c_t'] != null) {
          newHistory[dev] = (v['l_t'] as List).map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
          newCurrent[dev] = double.tryParse(v['c_t'].toString()) ?? 0.0;
        }
      });
      deviceHistory = newHistory;
      deviceCurrent = newCurrent;
    } catch (e) {
      // ignore parse error
    }
  }

  Future<void> connect() async {
    client = MqttServerClient(host, clientId);
    client.port = port;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.secure = useSSL;
    if (useSSL) {
      client.securityContext = SecurityContext.defaultContext;
    }
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();
    try {
      await client.connect();
      isConnected = client.connectionStatus?.state == MqttConnectionState.connected;
      if (isConnected) {
        await MqttConfigStorage().saveConfig(this);
      }
    } catch (e) {
      isConnected = false;
      client.disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    isConnected = false;
  }

  void onDisconnected() {
    isConnected = false;
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    TemperaturePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat),
            label: '温度',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class TemperaturePage extends StatefulWidget {
  @override
  State<TemperaturePage> createState() => _TemperaturePageState();
}

class _TemperaturePageState extends State<TemperaturePage> {
  final mqtt = MqttService();
  bool _connecting = false;
  bool _configChecked = false;
  final List<Color> chartColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.cyan,
    Colors.pink,
  ];
  Stream<List<MqttReceivedMessage<MqttMessage>>>? _mqttStream;

  @override
  void initState() {
    super.initState();
    _tryConnectMqtt();
  }

  Future<void> _tryConnectMqtt() async {
    await MqttConfigStorage().loadConfig(mqtt);
    setState(() {
      _configChecked = true;
    });
    if (_isConfigValid() && !mqtt.isConnected) {
      setState(() {
        _connecting = true;
      });
      await mqtt.connect();
      setState(() {
        _connecting = false;
      });
    }
    if (_isConfigValid() && mqtt.isConnected) {
      _subscribeAndListen();
    }
  }

  void _subscribeAndListen() {
    mqtt.client.subscribe(mqtt.topic, MqttQos.atLeastOnce);
    _mqttStream = mqtt.client.updates;
    _mqttStream?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      setState(() {
        mqtt.updateTemperatureData(pt);
      });
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
    setState(() {});
  }

  Color _fabColor() {
    if (!_configChecked || !_isConfigValid()) {
      return Colors.red;
    }
    if (mqtt.isConnected) {
      return Colors.green;
    }
    return Colors.red;
  }

  Widget _buildLegendShape(int idx) {
    final color = chartColors[idx % chartColors.length];
    switch (idx % 4) {
      case 0:
        // 圆形
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 1),
          ),
        );
      case 1:
        // 方形
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.white, width: 1),
          ),
        );
      case 2:
        // 三角形
        return CustomPaint(
          size: const Size(12, 12),
          painter: TrianglePainter(color: color),
        );
      case 3:
        // 菱形
        return Transform.rotate(
          angle: 0.785398, // 45度 = π/4
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        );
      default:
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 1),
          ),
        );
    }
  }

  Widget _buildChart() {
    if (mqtt.deviceHistory.isEmpty) {
      return const Center(child: Text('暂无温度数据'));
    }
    final ymin = mqtt.ymin;
    final ymax = mqtt.ymax;
    final interval = mqtt.yinterval;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RotatedBox(
        quarterTurns: 1,
        child: LineChart(
          LineChartData(
            minY: ymin,
            maxY: ymax,
            lineBarsData: mqtt.deviceHistory.entries.toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final dev = entry.value.key;
              final data = entry.value.value;
              return LineChartBarData(
                spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])],
                isCurved: true,
                color: chartColors[idx % chartColors.length],
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    // 根据传感器索引选择不同的形状
                    switch (idx % 4) {
                      case 0:
                        // 圆形
                        return FlDotCirclePainter(
                          radius: 4,
                          color: chartColors[idx % chartColors.length],
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      case 1:
                        // 方形 - 使用大一点的圆点来模拟方形效果
                        return FlDotCirclePainter(
                          radius: 5,
                          color: chartColors[idx % chartColors.length],
                          strokeWidth: 3,
                          strokeColor: Colors.white,
                        );
                      case 2:
                        // 三角形 - 使用小圆点
                        return FlDotCirclePainter(
                          radius: 3,
                          color: chartColors[idx % chartColors.length],
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      case 3:
                        // 菱形 - 使用中等圆点
                        return FlDotCirclePainter(
                          radius: 4,
                          color: chartColors[idx % chartColors.length],
                          strokeWidth: 2,
                          strokeColor: Colors.black,
                        );
                      default:
                        return FlDotCirclePainter(
                          radius: 4,
                          color: chartColors[idx % chartColors.length],
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                    }
                  },
                ),
                belowBarData: BarAreaData(show: false),
              );
            }).toList(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: interval,
                  getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0)),
                ),
              ),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(show: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (mqtt.deviceCurrent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: mqtt.deviceCurrent.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final dev = entry.value.key;
                      final tempList = mqtt.deviceHistory[dev] ?? [];
                      final current = mqtt.deviceCurrent[dev] ?? 0.0;
                      final max = tempList.isNotEmpty ? tempList.reduce((a, b) => a > b ? a : b) : 0.0;
                      final min = tempList.isNotEmpty ? tempList.reduce((a, b) => a < b ? a : b) : 0.0;
                      final avg = tempList.isNotEmpty ? (tempList.reduce((a, b) => a + b) / tempList.length) : 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLegendShape(idx),
                              const SizedBox(width: 4),
                              Text(dev),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(current.toStringAsFixed(1), style: const TextStyle(color: Colors.green)),
                              const SizedBox(width: 16),
                              Text(max.toStringAsFixed(1), style: const TextStyle(color: Colors.red)),
                              const SizedBox(width: 16),
                              Text(avg.toStringAsFixed(1), style: const TextStyle(color: Colors.yellow)),
                              const SizedBox(width: 16),
                              Text(min.toStringAsFixed(1), style: const TextStyle(color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _fabColor(),
        onPressed: _isConfigValid() && mqtt.isConnected ? _sendRefresh : null,
        child: const Icon(Icons.show_chart),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final mqtt = MqttService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _yminController = TextEditingController();
  final TextEditingController _ymaxController = TextEditingController();
  final TextEditingController _yintervalController = TextEditingController();
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await MqttConfigStorage().loadConfig(mqtt);
    _yminController.text = mqtt.ymin.toString();
    _ymaxController.text = mqtt.ymax.toString();
    _yintervalController.text = mqtt.yinterval.toString();
    setState(() {
      _configLoaded = true;
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _yminController.dispose();
    _ymaxController.dispose();
    _yintervalController.dispose();
    super.dispose();
  }

  void _sendTestMessage() {
    if (!mqtt.isConnected) return;
    final msg = _msgController.text.trim();
    if (msg.isEmpty) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(msg);
    mqtt.client.publishMessage(
      mqtt.topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    _msgController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              initialValue: mqtt.host,
              decoration: const InputDecoration(labelText: 'Host'),
              onChanged: (v) => mqtt.host = v,
            ),
            TextFormField(
              initialValue: mqtt.port.toString(),
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
              onChanged: (v) => mqtt.port = int.tryParse(v) ?? 1883,
            ),
            TextFormField(
              initialValue: mqtt.clientId,
              decoration: const InputDecoration(labelText: 'Client ID'),
              onChanged: (v) => mqtt.clientId = v,
            ),
            TextFormField(
              initialValue: mqtt.username,
              decoration: const InputDecoration(labelText: 'Username'),
              onChanged: (v) => mqtt.username = v,
            ),
            TextFormField(
              initialValue: mqtt.password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (v) => mqtt.password = v,
            ),
            TextFormField(
              initialValue: mqtt.topic,
              decoration: const InputDecoration(labelText: 'Topic'),
              onChanged: (v) => mqtt.topic = v,
            ),
            Row(
              children: [
                Checkbox(
                  value: mqtt.useSSL,
                  onChanged: (v) {
                    setState(() {
                      mqtt.useSSL = v ?? false;
                    });
                  },
                ),
                const Text('SSL连接'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('温度曲线Y轴设置', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yminController,
                    decoration: const InputDecoration(labelText: '最小温度'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => mqtt.ymin = double.tryParse(v) ?? -5.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _ymaxController,
                    decoration: const InputDecoration(labelText: '最大温度'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => mqtt.ymax = double.tryParse(v) ?? 50.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _yintervalController,
                    decoration: const InputDecoration(labelText: '温度间隔'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => mqtt.yinterval = double.tryParse(v) ?? 5.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await mqtt.connect();
                    setState(() {});
                  },
                  child: const Text('连接'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    mqtt.disconnect();
                    await MqttConfigStorage().saveConfig(mqtt);
                    setState(() {});
                  },
                  child: const Text('断开'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(mqtt.isConnected ? '已连接' : '未连接', style: TextStyle(color: Colors.blue)),
            if (mqtt.isConnected) ...[
              const Divider(height: 32),
              const Text('MQTT测试发送', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        labelText: '输入要发送的内容',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendTestMessage,
                    child: const Text('发送'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
