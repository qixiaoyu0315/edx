import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/mqtt_service.dart';
import '../services/mqtt_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/full_backup_service.dart';

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
  final TextEditingController _portController = TextEditingController();
  bool _configLoaded = false;
  bool _mqttExpanded = true; // 连接成功后自动折叠
  bool _fullscreen = false; // 全屏开关
  bool _didAutoCollapseOnce = false; // 避免重复自动折叠
  String _currentScheme = kDefaultScheme; // 主题色

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadFullscreenPref();
    _currentScheme = appScheme.value; // 同步当前主题色
  }

  Future<void> _loadConfig() async {
    await MqttConfigStorage().loadConfig(mqtt);
    _yminController.text = mqtt.ymin.toString();
    _ymaxController.text = mqtt.ymax.toString();
    _yintervalController.text = mqtt.yinterval.toString();
    _portController.text = mqtt.port.toString();
    if (mounted) {
      setState(() {
        _configLoaded = true;
        // 首次加载时根据连接状态设置折叠
        if (mqtt.isConnected) {
          _mqttExpanded = false;
          _didAutoCollapseOnce = true;
        }
      });
    }
  }

  Future<void> _loadFullscreenPref() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('fullscreen') ?? false;
    if (!mounted) return;
    setState(() => _fullscreen = value);
  }

  Future<void> _setFullscreen(bool value) async {
    setState(() => _fullscreen = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fullscreen', value);
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.black12,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _yminController.dispose();
    _ymaxController.dispose();
    _yintervalController.dispose();
    _portController.dispose();
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
    ShadToaster.of(context).show(ShadToast(
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
      alignment: Alignment.topCenter,
      description: const Text('测试消息已发送'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = ShadTheme.of(context);

    // 当页面显示且已连接时，自动折叠一次
    if (mqtt.isConnected && !_didAutoCollapseOnce && _mqttExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _mqttExpanded = false;
            _didAutoCollapseOnce = true;
          });
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                if (mqtt.isConnected) ...[
                  _buildTestMessageCard(theme),
                  const SizedBox(height: 16),
                ],
                _buildConnectionControls(theme),
                const SizedBox(height: 16),
                _buildThemeColorSelectCard(theme),
                const SizedBox(height: 16),
                _buildDisplaySettingsCard(theme),
                const SizedBox(height: 16),
                _buildBackupCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMqttSettingsCard(ShadThemeData theme) {
    return ShadCard(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('MQTT 设置', style: theme.textTheme.h4),
          Row(
            children: [
              Text(_mqttExpanded ? '收起' : '展开', style: theme.textTheme.muted),
              const SizedBox(width: 8),
              ShadButton.ghost(
                onPressed: () => setState(() => _mqttExpanded = !_mqttExpanded),
                child: Icon(
                  _mqttExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ],
          ),
        ],
      ),
      child: !_mqttExpanded
          ? const SizedBox.shrink()
          : Column(
              children: [
                ShadInputFormField(
                  initialValue: mqtt.host,
                  label: const Text('Host'),
                  onChanged: (v) => mqtt.host = v,
                ),
                ShadInputFormField(
                  controller: _portController,
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
                        setState(() {
                          mqtt.useSSL = v;
                          // Auto-switch common MQTT ports on SSL toggle
                          if (v) {
                            if (mqtt.port == 1883 ||
                                _portController.text == '1883') {
                              mqtt.port = 8883;
                              _portController.text = '8883';
                            }
                          } else {
                            if (mqtt.port == 8883 ||
                                _portController.text == '8883') {
                              mqtt.port = 1883;
                              _portController.text = '1883';
                            }
                          }
                        });
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
                setState(() {
                  if (mqtt.isConnected) {
                    _mqttExpanded = false; // 连接成功后折叠
                  }
                });
              },
              child: const Text('连接并保存'),
            ),
            const SizedBox(width: 16),
            ShadButton.destructive(
              onPressed: () async {
                mqtt.disconnect();
                await MqttConfigStorage().saveConfig(mqtt);
                setState(() {
                  _mqttExpanded = true; // 断开后默认展开
                });
              },
              child: const Text('断开'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          mqtt.isConnected ? '状态: 已连接' : '状态: 未连接',
          style: TextStyle(color: mqtt.isConnected ? Colors.green : Colors.red),
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
          ShadButton(onPressed: _sendTestMessage, child: const Text('发送')),
        ],
      ),
    );
  }

  Widget _buildDisplaySettingsCard(ShadThemeData theme) {
    return ShadCard(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('全屏显示', style: theme.textTheme.h4),
          Row(
            children: [
              const SizedBox(width: 8),
              ShadSwitch(
                value: _fullscreen,
                onChanged: (v) => _setFullscreen(v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeColorSelectCard(ShadThemeData theme) {
    final brightness = theme.brightness;
    Widget colorDot(Color color) => Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.border),
      ),
    );

    Widget optionRow(String name) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [colorDot(schemeFor(name, brightness).primary), Text(name)],
    );

    return ShadCard(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('主题色', style: theme.textTheme.h4),
          ShadSelect<String>(
            placeholder: const Text('选择主题色'),
            initialValue: _currentScheme,
            selectedOptionBuilder: (context, value) => optionRow(value),
            options: [
              for (final name in kSupportedSchemes)
                ShadOption<String>(value: name, child: optionRow(name)),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _currentScheme = value);
              appScheme.value = value;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('theme_scheme', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(ShadThemeData theme) {
    return ShadCard(
      title: Text('数据备份与恢复', style: theme.textTheme.h4),
      description: const Text('导出所有数据（成长数据、倒计时、MQTT配置）'),
      child: Row(
        children: [
          ShadButton(
            onPressed: () async {
              try {
                final saved = await FullBackupService.exportAllToZipToDownloads();
                if (!mounted) return;
                ShadToaster.of(context).show(ShadToast(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  alignment: Alignment.topCenter,
                  description: Text('已保存到下载目录: $saved'),
                ));
              } catch (e) {
                if (!mounted) return;
                ShadToaster.of(context).show(ShadToast(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  alignment: Alignment.topCenter,
                  description: Text('保存失败: $e'),
                ));
              }
            },
            child: const Text('保存到下载目录'),
          ),
        ],
      ),
    );
  }
}
