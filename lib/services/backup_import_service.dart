import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

import 'turtle_database_helper.dart';

class BackupImportService {
  // 导出为JSON备份，返回生成的文件
  static Future<File> exportJsonBackup() async {
    final file = await TurtleDatabaseHelper.instance.exportJson();
    return file;
  }

  // 通过系统文件保存对话框导出（SAF），返回保存后的路径/URI（不同平台返回值可能不同）
  static Future<String> exportJsonWithSystemPicker() async {
    final jsonString = await TurtleDatabaseHelper.instance.exportJsonString();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    final suggestedName = 'guigui_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final savedPath = await FileSaver.instance.saveFile(
      name: suggestedName,
      bytes: bytes,
      mimeType: MimeType.json,
    );
    return savedPath;
  }

  // 让用户选择一个JSON文件并导入
  static Future<void> importFromJsonWithPicker({bool clearExisting = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return; // 用户取消

    final path = result.files.single.path;
    if (path == null) return;

    final file = File(path);
    await TurtleDatabaseHelper.instance.importJson(file, clearExisting: clearExisting);
  }
}
