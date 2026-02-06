import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_config.dart';

/// 配置管理 Provider
final configProvider = StateNotifierProvider<ConfigNotifier, AppConfig>((ref) {
  return ConfigNotifier();
});

class ConfigNotifier extends StateNotifier<AppConfig> {
  static const String _configKey = 'app_config';

  ConfigNotifier() : super(AppConfig.empty()) {
    _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson != null) {
        final json = jsonDecode(configJson) as Map<String, dynamic>;
        state = AppConfig.fromJson(json);
      }
    } catch (e) {
      print('Error loading config: $e');
    }
  }

  /// 保存配置
  Future<void> saveConfig(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(config.toJson());
      await prefs.setString(_configKey, configJson);
      state = config;
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  /// 更新 GitHub 配置
  Future<void> updateGitHubConfig(GitHubConfig github) async {
    final newConfig = state.copyWith(github: github);
    await saveConfig(newConfig);
  }

  /// 更新全局图片回显域名
  Future<void> updateDisplayDomain(String displayDomain) async {
    final newEditor = state.editor.copyWith(displayDomain: displayDomain);
    final newConfig = state.copyWith(editor: newEditor);
    await saveConfig(newConfig);
  }

  /// 添加 OSS 配置
  Future<void> addOSSConfig(OSSConfig oss) async {
    final newList = [...state.ossList, oss];
    final newConfig = state.copyWith(ossList: newList);
    await saveConfig(newConfig);
  }

  /// 更新 OSS 配置
  Future<void> updateOSSConfig(String id, OSSConfig oss) async {
    final newList = state.ossList.map((item) {
      return item.id == id ? oss : item;
    }).toList();
    final newConfig = state.copyWith(ossList: newList);
    await saveConfig(newConfig);
  }

  /// 删除 OSS 配置
  Future<void> deleteOSSConfig(String id) async {
    final newList = state.ossList.where((item) => item.id != id).toList();
    final newConfig = state.copyWith(ossList: newList);
    await saveConfig(newConfig);
  }

  /// 切换 OSS 启用状态
  Future<void> toggleOSSEnabled(String id) async {
    final newList = state.ossList.map((item) {
      return item.id == id ? item.copyWith(enabled: !item.enabled) : item;
    }).toList();
    final newConfig = state.copyWith(ossList: newList);
    await saveConfig(newConfig);
  }

  /// 清空配置
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    state = AppConfig.empty();
  }
}
