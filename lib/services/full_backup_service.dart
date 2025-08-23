import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'turtle_database_helper.dart';

class FullBackupService {
  // 直接保存到公共下载目录（Android 优先），失败则抛出异常
  
  // 直接保存到公共下载目录（Android 优先），失败则回退到系统对话框
  static Future<String> exportAllToZipToDownloads() async {
    final result = await _createZipToTemp();
    String? targetPath;
    // 1) Android: 优先走平台通道写入公共 Downloads（MediaStore）
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.example.edx/backup');
        final bytes = await File(result.zipPath).readAsBytes();
        final saved = await channel.invokeMethod<String>('saveToDownloads', {
          'name': p.basename(result.zipPath),
          'bytes': bytes,
          'mime': 'application/zip',
        });
        if (saved != null && saved.isNotEmpty) {
          targetPath = saved;
        }
      } catch (_) {
        // ignore and try scoped Downloads as next fallback
      }
      // 2) 次选：scoped Downloads 目录（可能是应用作用域），不可用则继续兜底
      if (targetPath == null) {
        try {
          final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (dirs != null && dirs.isNotEmpty) {
            final downloads = dirs.first;
            final dest = p.join(downloads.path, p.basename(result.zipPath));
            await File(result.zipPath).copy(dest);
            targetPath = dest;
          }
        } catch (_) {}
      }
    }

    // 清理
    try { await Directory(result.workRoot).delete(recursive: true); } catch (_) {}
    try { await File(result.zipPath).delete(); } catch (_) {}
    if (targetPath == null) {
      throw Exception('无法写入下载目录');
    }
    return targetPath;
  }

  // 内部：构建工作目录 -> 打包到临时ZIP，返回路径
  static Future<_ZipBuildResult> _createZipToTemp() async {
    // 准备临时工作区
    final tempDir = await getTemporaryDirectory();
    final workRoot = Directory(p.join(tempDir.path, 'backup_${DateTime.now().millisecondsSinceEpoch}'));
    if (await workRoot.exists()) await workRoot.delete(recursive: true);
    await workRoot.create(recursive: true);

    final dbDir = Directory(p.join(workRoot.path, 'databases'))..createSync(recursive: true);
    final imgDir = Directory(p.join(workRoot.path, 'images'))..createSync(recursive: true);

    // 数据库
    final dbPath = await getDatabasesPath();
    final dbFiles = <String>['guigui.db', 'countdown.db', 'mqtt_config.db']
        .map((name) => File(p.join(dbPath, name)))
        .where((f) => f.existsSync())
        .toList();
    for (final f in dbFiles) {
      final dest = File(p.join(dbDir.path, p.basename(f.path)));
      await f.copy(dest.path);
    }

    // 图片
    final images = await _collectImagePaths();
    final copiedImages = <Map<String, String>>[];
    for (final path in images) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final savedName = _uniqueName(imgDir.path, p.basename(path));
          final dest = File(p.join(imgDir.path, savedName));
          await file.copy(dest.path);
          copiedImages.add({'original': path, 'saved': 'images/$savedName'});
        }
      } catch (_) {}
    }

    // 偏好
    final prefs = await SharedPreferences.getInstance();
    final prefsData = <String, dynamic>{
      'fullscreen': prefs.getBool('fullscreen') ?? false,
      'theme_scheme': prefs.getString('theme_scheme'),
    };

    // 元数据
    final metadata = {
      'format': 'guigui_full_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'databases': dbFiles.map((f) => 'databases/${p.basename(f.path)}').toList(),
      'images': copiedImages,
      'prefs': prefsData,
      'notes': '该ZIP包含SQLite数据库、相关图片与关键偏好，可用于完整备份。',
    };
    final metadataFile = File(p.join(workRoot.path, 'metadata.json'));
    await metadataFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));

    // 打包
    final encoder = ZipFileEncoder();
    final zipPath = p.join(tempDir.path, 'guigui_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
    encoder.create(zipPath);
    encoder.addDirectory(workRoot);
    encoder.close();

    return _ZipBuildResult(workRoot.path, zipPath);
  }

  // 收集图片路径（去重）
  static Future<Set<String>> _collectImagePaths() async {
    final set = <String>{};
    final db = await TurtleDatabaseHelper.instance.database;

    // turtles 表
    try {
      final turtles = await db.query(TurtleDatabaseHelper.tableTurtles, columns: ['photoPath']);
      for (final row in turtles) {
        final pth = row['photoPath'] as String?;
        if (pth != null && pth.isNotEmpty) set.add(pth);
      }
    } catch (_) {}

    // records 表
    try {
      final recs = await db.query(TurtleDatabaseHelper.tableRecords, columns: ['photoPath']);
      for (final row in recs) {
        final pth = row['photoPath'] as String?;
        if (pth != null && pth.isNotEmpty) set.add(pth);
      }
    } catch (_) {}

    return set;
  }

  static String _uniqueName(String dir, String base) {
    var name = base;
    var i = 1;
    while (File(p.join(dir, name)).existsSync()) {
      final ext = p.extension(base);
      final stem = p.basenameWithoutExtension(base);
      name = '${stem}_$i$ext';
      i++;
    }
    return name;
  }
}

class _ZipBuildResult {
  final String workRoot;
  final String zipPath;
  _ZipBuildResult(this.workRoot, this.zipPath);
}
