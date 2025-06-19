import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

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
      version: 1,
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
            useSSL INTEGER
          )
        ''');
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

  MqttService._internal();

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
  Map<String, List<double>> deviceHistory = {};
  Map<String, double> deviceCurrent = {};
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
      _handleMqttMessage(pt);
    });
  }

  void _handleMqttMessage(String payload) {
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
      setState(() {
        deviceHistory = newHistory;
        deviceCurrent = newCurrent;
      });
    } catch (e) {
      // ignore parse error
    }
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

  Widget _buildChart() {
    if (deviceHistory.isEmpty) {
      return const Center(child: Text('暂无温度数据'));
    }
    final maxLen = deviceHistory.values.map((l) => l.length).fold<int>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minY: deviceHistory.values.expand((l) => l).fold<double>(1000, (a, b) => a < b ? a : b),
          maxY: deviceHistory.values.expand((l) => l).fold<double>(-1000, (a, b) => a > b ? a : b),
          lineBarsData: deviceHistory.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final dev = entry.value.key;
            final data = entry.value.value;
            return LineChartBarData(
              spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])],
              isCurved: true,
              color: chartColors[idx % chartColors.length],
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              // 可加legend
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _buildChart()),
          if (deviceCurrent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 16,
                children: deviceCurrent.entries.toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final dev = entry.value.key;
                  final temp = entry.value.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 16, height: 16, color: chartColors[idx % chartColors.length]),
                      const SizedBox(width: 4),
                      Text('$dev: $temp°C'),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
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
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await MqttConfigStorage().loadConfig(mqtt);
    setState(() {
      _configLoaded = true;
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
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
                  onPressed: () {
                    mqtt.disconnect();
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
