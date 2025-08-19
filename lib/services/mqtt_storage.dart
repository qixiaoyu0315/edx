import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'mqtt_service.dart';

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
