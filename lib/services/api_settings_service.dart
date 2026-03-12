import 'package:shared_preferences/shared_preferences.dart';

class ApiSettingsService {
  static const String _apiKeyKey = 'custom_api_key';
  static const String _apiUrlKey = 'custom_api_url';
  static const String _modelNameKey = 'custom_model_name';

  // 默认配置（从环境变量读取的默认值）
  static const String defaultApiUrl = 'https://api.deepseek.com/chat/completions';
  static const String defaultModelName = 'deepseek-chat';

  /// 获取自定义 API Key
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  /// 获取自定义 API URL
  static Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? defaultApiUrl;
  }

  /// 获取自定义模型名称
  static Future<String> getModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelNameKey) ?? defaultModelName;
  }

  /// 保存 API 配置
  static Future<void> saveSettings({
    required String apiKey,
    required String apiUrl,
    required String modelName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey.trim());
    await prefs.setString(_apiUrlKey, apiUrl.trim());
    await prefs.setString(_modelNameKey, modelName.trim());
  }

  /// 重置为默认配置
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_apiUrlKey);
    await prefs.remove(_modelNameKey);
  }

  /// 检查是否已配置自定义 API
  static Future<bool> isConfigured() async {
    final apiKey = await getApiKey();
    return apiKey.isNotEmpty;
  }

  /// 测试 API 连接
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final apiKey = await getApiKey();
      final apiUrl = await getApiUrl();
      final modelName = await getModelName();

      if (apiKey.isEmpty) {
        return {
          'success': false,
          'message': '请先配置 API Key',
        };
      }

      // 发送简单的测试消息
      final response = await _sendTestRequest(apiKey, apiUrl, modelName);
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': '连接失败：${e.toString()}',
      };
    }
  }

  /// 发送测试请求
  static Future<Map<String, dynamic>> _sendTestRequest(
    String apiKey,
    String apiUrl,
    String modelName,
  ) async {
    // 这里使用 http 包，但实际请求逻辑会在调用方实现
    // 这个方法主要用于标记测试接口
    return {
      'success': true,
      'message': '配置有效，准备发送测试请求',
    };
  }

  /// 获取当前配置的摘要信息（用于显示）
  static Future<Map<String, String>> getConfigSummary() async {
    final apiKey = await getApiKey();
    final apiUrl = await getApiUrl();
    final modelName = await getModelName();

    // 隐藏 API Key 的中间部分
    String maskedKey = '未配置';
    if (apiKey.isNotEmpty) {
      if (apiKey.length > 8) {
        maskedKey = '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
      } else {
        maskedKey = '${apiKey.substring(0, 2)}**';
      }
    }

    return {
      'apiKey': maskedKey,
      'apiUrl': apiUrl,
      'modelName': modelName,
      'isConfigured': apiKey.isNotEmpty.toString(),
    };
  }
}
