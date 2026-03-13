import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

/// 背景设置服务
class BackgroundSettingsService {
  static const String _backgroundPathKey = 'custom_background_path';
  static const String _backgroundBlurKey = 'custom_background_blur';
  static const String _backgroundEnabledKey = 'custom_background_enabled';
  
  /// 获取背景图片路径
  static Future<String?> getBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundPathKey);
  }
  
  /// 获取背景虚化程度（0.0 - 10.0）
  static Future<double> getBackgroundBlur() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_backgroundBlurKey) ?? 5.0;
  }
  
  /// 获取背景是否启用
  static Future<bool> isBackgroundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backgroundEnabledKey) ?? false;
  }
  
  /// 保存背景图片路径
  static Future<void> saveBackgroundPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundPathKey, path);
  }
  
  /// 保存背景虚化程度
  static Future<void> saveBackgroundBlur(double blur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_backgroundBlurKey, blur);
  }
  
  /// 保存背景启用状态
  static Future<void> saveBackgroundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundEnabledKey, enabled);
  }
  
  /// 从相册选择图片（Windows 平台不支持裁切）
  static Future<String?> pickAndCropImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // 选择图片
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      
      if (pickedFile == null) {
        debugPrint('用户取消了图片选择');
        return null;
      }
      
      debugPrint('选择的图片路径：${pickedFile.path}');
      
      // 将图片复制到应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'background_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${directory.path}/$fileName';
      
      final File savedFile = await File(pickedFile.path).copy(savedPath);
      debugPrint('背景图片已保存到：$savedPath');
      
      return savedFile.path;
    } catch (e) {
      debugPrint('选择背景图片失败：$e');
      return null;
    }
  }
  
  /// 获取背景图片文件
  static Future<File?> getBackgroundFile() async {
    final path = await getBackgroundPath();
    if (path == null || path.isEmpty) {
      return null;
    }
    
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    
    return null;
  }
  
  /// 删除背景图片
  static Future<void> removeBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_backgroundPathKey);
    
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    await prefs.remove(_backgroundPathKey);
    await prefs.remove(_backgroundBlurKey);
    await prefs.remove(_backgroundEnabledKey);
  }
  
  /// 获取所有设置
  static Future<Map<String, dynamic>> getAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'path': prefs.getString(_backgroundPathKey),
      'blur': prefs.getDouble(_backgroundBlurKey) ?? 5.0,
      'enabled': prefs.getBool(_backgroundEnabledKey) ?? false,
    };
  }
}
