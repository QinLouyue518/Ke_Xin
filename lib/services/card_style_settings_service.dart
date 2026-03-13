import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 卡片样式设置服务
class CardStyleSettingsService {
  static const String _cardColorKey = 'reading_card_color';
  static const String _cardOpacityKey = 'reading_card_opacity';
  static const String _cardStyleEnabledKey = 'reading_card_style_enabled';
  
  /// 默认卡片颜色
  static const Color defaultCardColor = Colors.white;
  
  /// 默认不透明度 (0.9 = 90%)
  static const double defaultOpacity = 0.9;
  
  /// 获取卡片颜色
  static Future<Color> getCardColor() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_cardColorKey);
    return value != null ? Color(value) : defaultCardColor;
  }
  
  /// 获取卡片不透明度 (0.0 - 1.0)
  static Future<double> getCardOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_cardOpacityKey) ?? defaultOpacity;
  }
  
  /// 获取卡片样式是否启用
  static Future<bool> isCardStyleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cardStyleEnabledKey) ?? false;
  }
  
  /// 保存卡片颜色
  static Future<void> saveCardColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cardColorKey, color.toARGB32());
  }
  
  /// 保存卡片不透明度
  static Future<void> saveCardOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cardOpacityKey, opacity);
  }
  
  /// 保存卡片样式启用状态
  static Future<void> saveCardStyleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cardStyleEnabledKey, enabled);
  }
  
  /// 重置为默认设置
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cardColorKey);
    await prefs.remove(_cardOpacityKey);
    await prefs.remove(_cardStyleEnabledKey);
  }
  
  /// 获取所有设置
  static Future<Map<String, dynamic>> getAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'color': prefs.getInt(_cardColorKey) ?? defaultCardColor.toARGB32(),
      'opacity': prefs.getDouble(_cardOpacityKey) ?? defaultOpacity,
      'enabled': prefs.getBool(_cardStyleEnabledKey) ?? false,
    };
  }
  
  /// 获取不透明度百分比 (0-100)
  static double opacityToPercentage(double opacity) {
    return (opacity * 100).round().toDouble();
  }
  
  /// 将百分比转换为不透明度
  static double percentageToOpacity(double percentage) {
    return percentage / 100;
  }
}
