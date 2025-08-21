import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/countdown_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'countdown.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE countdown_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        milliseconds INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE timed_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        UNIQUE(hour, minute)
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert('settings', {'key': 'isTimingEnabled', 'value': 'false'});
  }

  // CountdownItem methods
  Future<List<CountdownItem>> getCountdownItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('countdown_items', orderBy: 'name');
    return List.generate(maps.length, (i) {
      return CountdownItem(
        id: maps[i]['id'],
        name: maps[i]['name'],
        milliseconds: maps[i]['milliseconds'],
      );
    });
  }

  Future<void> insertCountdownItem(CountdownItem item) async {
    final db = await database;
    await db.insert(
      'countdown_items',
      {'id': item.id, 'name': item.name, 'milliseconds': item.milliseconds},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCountdownItem(CountdownItem item) async {
    final db = await database;
    await db.update(
      'countdown_items',
      {'name': item.name, 'milliseconds': item.milliseconds},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteCountdownItem(String id) async {
    final db = await database;
    await db.delete(
      'countdown_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // TimedSchedule methods
  Future<List<TimeOfDay>> getTimedSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('timed_schedules', orderBy: 'hour, minute');
    return List.generate(maps.length, (i) {
      return TimeOfDay(hour: maps[i]['hour'], minute: maps[i]['minute']);
    });
  }

  Future<void> insertTimedSchedule(TimeOfDay time) async {
    final db = await database;
    await db.insert(
      'timed_schedules',
      {'hour': time.hour, 'minute': time.minute},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteTimedSchedule(TimeOfDay time) async {
    final db = await database;
    await db.delete(
      'timed_schedules',
      where: 'hour = ? AND minute = ?',
      whereArgs: [time.hour, time.minute],
    );
  }

  Future<void> updateTimedSchedule(TimeOfDay oldTime, TimeOfDay newTime) async {
    final db = await database;
    await db.update(
      'timed_schedules',
      {'hour': newTime.hour, 'minute': newTime.minute},
      where: 'hour = ? AND minute = ?',
      whereArgs: [oldTime.hour, oldTime.minute],
    );
  }

  // Settings methods
  Future<bool> getIsTimingEnabled() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['isTimingEnabled'],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] == 'true';
    }
    return false; // Default value
  }

  Future<void> setIsTimingEnabled(bool isEnabled) async {
    final db = await database;
    // Use insert with replace to handle first-time write when key does not exist
    await db.insert(
      'settings',
      {'key': 'isTimingEnabled', 'value': isEnabled.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Last sent summary methods
  Future<String?> getLastSentSummary() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['lastSentSummary'],
    );
    if (maps.isNotEmpty) return maps.first['value'] as String;
    return null;
  }

  Future<void> setLastSentSummary(String summary) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'lastSentSummary', 'value': summary},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastSentAt() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['lastSentAt'],
    );
    if (maps.isNotEmpty) {
      final v = maps.first['value'] as String;
      return DateTime.tryParse(v);
    }
    return null;
  }

  Future<void> setLastSentAt(DateTime dt) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'lastSentAt', 'value': dt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
