import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../services/mqtt_service.dart';
import '../services/mqtt_storage.dart';

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
            const Text(
              '温度曲线Y轴设置',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                    onChanged: (v) =>
                        mqtt.yinterval = double.tryParse(v) ?? 5.0,
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
            Text(
              mqtt.isConnected ? '已连接' : '未连接',
              style: TextStyle(color: Colors.blue),
            ),
            if (mqtt.isConnected) ...[
              const Divider(height: 32),
              const Text(
                'MQTT测试发送',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(labelText: '输入要发送的内容'),
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
