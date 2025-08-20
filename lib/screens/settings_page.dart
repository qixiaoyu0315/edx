import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/mqtt_service.dart';
import '../services/mqtt_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final mqtt = MqttService();
  final _formKey = GlobalKey<ShadFormState>();
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
    if (mounted) {
      setState(() {
        _configLoaded = true;
      });
    }
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
    ShadToaster.of(context).show(
      ShadToast(
        description: const Text('测试消息已发送'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = ShadTheme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ShadForm(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMqttSettingsCard(theme),
              const SizedBox(height: 16),
              _buildYAxisSettingsCard(theme),
              const SizedBox(height: 16),
              _buildConnectionControls(theme),
              if (mqtt.isConnected) ...[
                const SizedBox(height: 16),
                _buildTestMessageCard(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMqttSettingsCard(ShadThemeData theme) {
    return ShadCard(
      title: Text('MQTT 设置', style: theme.textTheme.h4),
      child: Column(
        children: [
          ShadInputFormField(
            initialValue: mqtt.host,
            label: const Text('Host'),
            onChanged: (v) => mqtt.host = v,
          ),
          ShadInputFormField(
            initialValue: mqtt.port.toString(),
            label: const Text('Port'),
            keyboardType: TextInputType.number,
            onChanged: (v) => mqtt.port = int.tryParse(v) ?? 1883,
          ),
          ShadInputFormField(
            initialValue: mqtt.clientId,
            label: const Text('Client ID'),
            onChanged: (v) => mqtt.clientId = v,
          ),
          ShadInputFormField(
            initialValue: mqtt.username,
            label: const Text('Username'),
            onChanged: (v) => mqtt.username = v,
          ),
          ShadInputFormField(
            initialValue: mqtt.password,
            label: const Text('Password'),
            obscureText: true,
            onChanged: (v) => mqtt.password = v,
          ),
          ShadInputFormField(
            initialValue: mqtt.topic,
            label: const Text('Topic'),
            onChanged: (v) => mqtt.topic = v,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ShadCheckbox(
                value: mqtt.useSSL,
                onChanged: (v) {
                  setState(() => mqtt.useSSL = v);
                },
              ),
              const SizedBox(width: 8),
              const Text('SSL连接'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYAxisSettingsCard(ShadThemeData theme) {
    return ShadCard(
      title: Text('温度曲线 Y 轴设置', style: theme.textTheme.h4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShadInputFormField(
              controller: _yminController,
              label: const Text('最小温度'),
              keyboardType: TextInputType.number,
              onChanged: (v) => mqtt.ymin = double.tryParse(v) ?? -5.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadInputFormField(
              controller: _ymaxController,
              label: const Text('最大温度'),
              keyboardType: TextInputType.number,
              onChanged: (v) => mqtt.ymax = double.tryParse(v) ?? 50.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadInputFormField(
              controller: _yintervalController,
              label: const Text('温度间隔'),
              keyboardType: TextInputType.number,
              onChanged: (v) => mqtt.yinterval = double.tryParse(v) ?? 5.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionControls(ShadThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShadButton(
              onPressed: () async {
                await mqtt.connect();
                setState(() {});
              },
              child: const Text('连接'),
            ),
            const SizedBox(width: 16),
            ShadButton.destructive(
              onPressed: () async {
                mqtt.disconnect();
                await MqttConfigStorage().saveConfig(mqtt);
                setState(() {});
              },
              child: const Text('断开并保存'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          mqtt.isConnected ? '状态: 已连接' : '状态: 未连接',
          style: TextStyle(
            color: mqtt.isConnected ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildTestMessageCard(ShadThemeData theme) {
    return ShadCard(
      title: Text('MQTT 测试发送', style: theme.textTheme.h4),
      child: Row(
        children: [
          Expanded(
            child: ShadInput(
              controller: _msgController,
              placeholder: const Text('输入要发送的内容'),
            ),
          ),
          const SizedBox(width: 8),
          ShadButton(
            onPressed: _sendTestMessage,
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }
}
