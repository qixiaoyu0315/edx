import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sort_option.dart';

class SortConfigService {
  static const String _sortConfigKey = 'sort_config';

  // 获取排序配置
  static Future<SortConfig> getSortConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_sortConfigKey);
    
    if (configJson != null) {
      try {
        final configMap = jsonDecode(configJson);
        return SortConfig.fromJson(configMap);
      } catch (e) {
        // 如果解析失败，返回默认配置
        return SortConfig.defaultConfig;
      }
    }
    
    return SortConfig.defaultConfig;
  }

  // 保存排序配置
  static Future<void> saveSortConfig(SortConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = jsonEncode(config.toJson());
    await prefs.setString(_sortConfigKey, configJson);
  }

  // 重置为默认配置
  static Future<void> resetToDefault() async {
    await saveSortConfig(SortConfig.defaultConfig);
  }
}
