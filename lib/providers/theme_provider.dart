import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式状态
class ThemeModeState {
  final ThemeMode themeMode;

  ThemeModeState({this.themeMode = ThemeMode.system});

  ThemeModeState copyWith({ThemeMode? themeMode}) {
    return ThemeModeState(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// 主题模式 Notifier
class ThemeModeNotifier extends StateNotifier<ThemeModeState> {
  ThemeModeNotifier() : super(ThemeModeState()) {
    _loadThemeMode();
  }

  static const String _themeModeKey = 'theme_mode';

  /// 加载主题模式
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themeModeKey);

      if (themeModeString != null) {
        final themeMode = _parseThemeMode(themeModeString);
        state = state.copyWith(themeMode: themeMode);
      }
    } catch (e) {
      print('Error loading theme mode: $e');
    }
  }

  /// 保存主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
      state = state.copyWith(themeMode: mode);
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }

  /// 解析主题模式字符串
  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }
}

/// 主题模式 Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeModeState>((ref) {
  return ThemeModeNotifier();
});
