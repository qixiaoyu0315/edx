import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
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

  // 通过系统文件选择器选择ZIP并执行恢复
  // 返回摘要字符串，包含成功/跳过项统计；返回 null 表示用户取消
  static Future<String?> restoreAllFromZipWithPicker() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (pick == null || pick.files.isEmpty) return null; // 用户取消
    final path = pick.files.single.path;
    if (path == null) return null;
    return await restoreAllFromZip(File(path));
  }

  // 从给定ZIP文件恢复
  static Future<String> restoreAllFromZip(File zipFile) async {
    final tempDir = await getTemporaryDirectory();
    final workRoot = Directory(p.join(tempDir.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'));
    if (await workRoot.exists()) await workRoot.delete(recursive: true);
    await workRoot.create(recursive: true);

    // 解压（放到后台 isolate 防止阻塞 UI）
    print('[Restore] Unzip start: ${zipFile.path}');
    await _unzipToDir(zipFile, workRoot.path);
    print('[Restore] Unzip done to: ${workRoot.path}');

    // 定位备份根目录（兼容 zip 中多包一层 backup_* 目录的情况）
    final baseDir = await _findBackupBaseDir(workRoot);
    print('[Restore] Base dir resolved: ${baseDir.path}');

    // 读取元数据
    final metaFile = File(p.join(baseDir.path, 'metadata.json'));
    if (!await metaFile.exists()) {
      // 列出一层目录帮助诊断
      try {
        final children = baseDir.listSync().map((e) => e.path.split('/').last).join(', ');
        print('[Restore][Warn] metadata.json not found in ${baseDir.path}. children: $children');
      } catch (_) {}
      await _cleanupDir(workRoot);
      throw Exception('备份ZIP缺少 metadata.json');
    }
    final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    if (meta['format'] != 'guigui_full_backup') {
      await _cleanupDir(workRoot);
      throw Exception('备份格式不匹配');
    }

    // 关闭数据库，准备覆盖
    await TurtleDatabaseHelper.instance.close();

    // 恢复数据库文件
    final dbPath = await getDatabasesPath();
    int dbRestored = 0;
    for (final rel in (meta['databases'] as List<dynamic>? ?? [])) {
      final src = File(p.join(baseDir.path, rel as String));
      if (await src.exists()) {
        final dest = File(p.join(dbPath, p.basename(rel)));
        await dest.parent.create(recursive: true);
        // 清理旧 DB 及伴随的 -wal/-shm，避免锁或不一致
        try { if (await dest.exists()) await dest.delete(); } catch (_) {}
        try { final wal = File('${dest.path}-wal'); if (await wal.exists()) await wal.delete(); } catch (_) {}
        try { final shm = File('${dest.path}-shm'); if (await shm.exists()) await shm.delete(); } catch (_) {}
        await src.copy(dest.path);
        dbRestored++;
      }
    }

    // 恢复图片到应用文档目录 images_restored 下
    final docs = await getApplicationDocumentsDirectory();
    final restoreImagesDir = Directory(p.join(docs.path, 'images_restored'));
    await restoreImagesDir.create(recursive: true);
    int imgRestored = 0;
    final imageMappings = <String, String>{}; // original -> newAbsolute
    for (final item in (meta['images'] as List<dynamic>? ?? [])) {
      final map = (item as Map).cast<String, dynamic>();
      final original = map['original'] as String?;
      final saved = map['saved'] as String?; // e.g. images/xxx.jpg
      if (saved == null) continue;
      final src = File(p.join(baseDir.path, saved));
      if (!await src.exists()) continue;
      final destName = _uniqueName(restoreImagesDir.path, p.basename(saved));
      final dest = File(p.join(restoreImagesDir.path, destName));
      await src.copy(dest.path);
      imgRestored++;
      if (original != null && original.isNotEmpty) {
        imageMappings[original] = dest.path;
      }
    }

    // 重写数据库中的图片路径（仅 guigui.db）
    final db = await TurtleDatabaseHelper.instance.database;
    final batch = db.batch();
    for (final entry in imageMappings.entries) {
      batch.update(
        TurtleDatabaseHelper.tableTurtles,
        {'photoPath': entry.value},
        where: 'photoPath = ?',
        whereArgs: [entry.key],
      );
      batch.update(
        TurtleDatabaseHelper.tableRecords,
        {'photoPath': entry.value},
        where: 'photoPath = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);

    // 恢复偏好（仅已知键）
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsData = (meta['prefs'] as Map?)?.cast<String, dynamic>() ?? {};
      if (prefsData.containsKey('fullscreen')) {
        await prefs.setBool('fullscreen', prefsData['fullscreen'] == true);
      }
      if (prefsData['theme_scheme'] is String) {
        await prefs.setString('theme_scheme', prefsData['theme_scheme'] as String);
      }
    } catch (_) {}

    await _cleanupDir(workRoot);

    return '数据库恢复: $dbRestored 个，图片恢复: $imgRestored 张';
  }

  // 在后台 isolate 解压，避免阻塞 UI
  static Future<void> _unzipToDir(File zip, String outDir) async {
    await Isolate.run(() {
      final bytes = zip.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      int files = 0, dirs = 0, logged = 0;
      for (final entry in archive) {
        String normalized = p.normalize(entry.name.replaceAll('\\', '/'));
        // 强制为相对路径，去掉前导 '/'
        while (p.isAbsolute(normalized)) {
          if (normalized.length <= 1) break;
          normalized = normalized.substring(1);
        }
        final outPath = p.join(outDir, normalized);
        // 防目录穿越
        final safePath = p.normalize(outPath);
        if (!safePath.startsWith(p.normalize(outDir))) {
          continue;
        }
        if (logged < 5) {
          // ignore: avoid_print
          print('[Restore] Entry: ${entry.isFile ? 'F' : 'D'} $normalized');
          logged++;
        }
        if (entry.isFile) {
          final outFile = File(safePath);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(entry.content as List<int>);
          files++;
        } else {
          Directory(safePath).createSync(recursive: true);
          dirs++;
        }
      }
      // 记录统计
      // ignore: avoid_print
      print('[Restore] Extracted entries -> files:$files dirs:$dirs');
    });
  }

  // 在解压目录中查找 metadata.json 所在的基准目录
  static Future<Directory> _findBackupBaseDir(Directory root) async {
    final metaAtRoot = File(p.join(root.path, 'metadata.json'));
    if (await metaAtRoot.exists()) return root;

    Directory? found;
    Future<void> dfs(Directory dir, int depth) async {
      if (depth > 5 || found != null) return;
      final entries = dir.listSync();
      for (final e in entries) {
        if (found != null) return;
        if (e is Directory) {
          final f = File(p.join(e.path, 'metadata.json'));
          if (await f.exists()) { found = e; return; }
          await dfs(e, depth + 1);
        }
      }
    }

    await dfs(root, 0);
    return found ?? root;
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

  static Future<void> _cleanupDir(Directory dir) async {
    try { await dir.delete(recursive: true); } catch (_) {}
  }
}

class _ZipBuildResult {
  final String workRoot;
  final String zipPath;
  _ZipBuildResult(this.workRoot, this.zipPath);
}
