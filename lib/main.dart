import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';

void main() {
  runApp(const MainApp());
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

class TemperaturePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('温度页面'),
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
