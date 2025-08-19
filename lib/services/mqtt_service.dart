import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

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

  // 缓存温度数据
  Map<String, List<double>> deviceHistory = {};
  Map<String, double> deviceCurrent = {};

  MqttService._internal();

  // 处理温度数据
  void updateTemperatureData(String payload) {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        (payload.isNotEmpty) ? (jsonDecode(payload)) : {},
      );
      final Map<String, List<double>> newHistory = {};
      final Map<String, double> newCurrent = {};
      data.forEach((dev, v) {
        if (v is Map<String, dynamic> && v['l_t'] is List && v['c_t'] != null) {
          newHistory[dev] = (v['l_t'] as List)
              .map((e) => double.tryParse(e.toString()) ?? 0.0)
              .toList();
          newCurrent[dev] = double.tryParse(v['c_t'].toString()) ?? 0.0;
        }
      });
      deviceHistory = newHistory;
      deviceCurrent = newCurrent;
    } catch (e) {
      // ignore parse error
    }
  }

  Future<MqttConnectionState?> connect() async {
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
      isConnected =
          client.connectionStatus?.state == MqttConnectionState.connected;
      return client.connectionStatus?.state;
    } catch (e) {
      isConnected = false;
      client.disconnect();
      return MqttConnectionState.faulted;
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
