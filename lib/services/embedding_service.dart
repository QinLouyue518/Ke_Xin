import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_settings_service.dart';

class EmbeddingService {
  // 默认使用 SiliconFlow 的 BAAI/bge-m3 模型，因为它免费且效果好
  static const String _defaultModel = "BAAI/bge-m3";
  static const String _defaultUrl = "https://api.siliconflow.cn/v1/embeddings";

  static Future<List<double>?> getEmbedding(String text) async {
    if (text.trim().isEmpty) return null;

    // 清洗文本：去掉换行，防止某些 API 报错
    final cleanText = text.replaceAll('\n', ' ');

    // 从自定义配置读取 API Key
    final apiKey = await ApiSettingsService.getApiKey();
    
    // 如果没有配置 API Key，返回 null
    if (apiKey.isEmpty) {
      return null;
    }

    // 使用自定义 API URL 或默认值
    // 注意：embedding 服务可能需要单独的 URL，这里优先使用自定义配置
    String apiUrl = _defaultUrl;
    String model = _defaultModel;

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "input": cleanText,
          "model": model,
          "encoding_format": "float"
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> embedding = data['data'][0]['embedding'];
        return embedding.map((e) => e as double).toList();
      } else {
        print('Embedding API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Embedding Network Error: $e');
    }
    return null;
  }
}


