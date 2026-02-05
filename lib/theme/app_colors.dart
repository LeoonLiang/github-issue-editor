import 'package:flutter/material.dart';

/// 应用颜色定义
class AppColors {
  AppColors._();

  // 主色
  static const Color primary = Color(0xFF0d59f2);

  // 浅色模式颜色
  static const Color lightBackground = Color(0xFFf5f6f8);
  static const Color lightCard = Color(0xFFffffff);
  static const Color lightTextPrimary = Color(0xFF1e293b); // slate-900
  static const Color lightTextSecondary = Color(0xFF64748b); // slate-500
  static const Color lightTextTertiary = Color(0xFF94a3b8); // slate-400
  static const Color lightBorder = Color(0xFFe2e8f0); // slate-200
  static const Color lightDivider = Color(0xFFf1f5f9); // slate-100

  // 深色模式颜色
  static const Color darkBackground = Color(0xFF101622);
  static const Color darkCard = Color(0xFF1b2333);
  static const Color darkCardAlt = Color(0xFF1a212e);
  static const Color darkTextPrimary = Color(0xFFffffff);
  static const Color darkTextSecondary = Color(0xFF9ca6ba);
  static const Color darkTextTertiary = Color(0xFF64748b); // slate-500
  static const Color darkBorder = Color(0xFF334155); // slate-800
  static const Color darkDivider = Color(0xFF1e293b); // slate-900

  // 状态颜色
  static const Color success = Color(0xFF10b981); // green-500
  static const Color successLight = Color(0xFFd1fae5); // green-100
  static const Color successDark = Color(0xFF065f46); // green-900

  static const Color error = Color(0xFFef4444); // red-500
  static const Color errorLight = Color(0xFFfee2e2); // red-100
  static const Color errorDark = Color(0xFF7f1d1d); // red-900

  static const Color warning = Color(0xFFf59e0b); // amber-500
  static const Color info = Color(0xFF3b82f6); // blue-500

  // 特殊颜色
  static const Color primaryLight = Color(0xFFdbeafe); // blue-100
  static const Color primaryDark = Color(0xFF1e3a8a); // blue-900
}
