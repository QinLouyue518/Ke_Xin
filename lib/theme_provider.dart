import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✨ 定义可选的主题色方案
class AppTheme {
  static const Color morandiBlue = Color(0xFF7CA1B4);   // 默认：静谧蓝
  static const Color matchaGreen = Color(0xFF98B884);   // 抹茶绿
  static const Color sakuraPink = Color(0xFFE8ADAA);    // 樱花粉
  static const Color autumnAmber = Color(0xFFD6A06D);   // 秋日琥珀
  static const Color lilacPurple = Color(0xFFAFA2C4);   // 丁香紫
  static const Color deepSpace = Color(0xFF5C6BC0);     // 深空靛
  
  static final Map<String, Color> themeColors = {
    '静谧蓝': morandiBlue,
    '抹茶绿': matchaGreen,
    '樱花粉': sakuraPink,
    '秋日琥珀': autumnAmber,
    '丁香紫': lilacPurple,
    '深空靛': deepSpace,
  };
}

class ThemeProvider with ChangeNotifier {
  Color _themeColor = AppTheme.morandiBlue;

  Color get themeColor => _themeColor;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('theme_color');
    if (colorValue != null) {
      _themeColor = Color(colorValue);
      notifyListeners();
    }
  }

  void setThemeColor(Color color) async {
    _themeColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
  }
}

