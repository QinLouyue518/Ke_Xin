import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/embedding_service.dart'; // 引入嵌入服务

class VectorStoreService {
  static const String _vectorStoreKey = 'diary_vector_store'; // SharedPreferences key

  // 假设的向量存储结构：Map<String, Map<String, dynamic>>
  // 外层key是日记日期 (e.g., "2023-10-26")
  // 内层Map包含 'content' (原始文本) 和 'vector' (List<double>)

  // 初始化或加载向量存储 (在实际应用中，你可能需要在启动时加载)
  static Future<Map<String, Map<String, dynamic>>> _loadVectorStore() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_vectorStoreKey);
    if (jsonString != null) {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value as Map<String, dynamic>));
    }
    return {};
  }

  // 保存向量存储
  static Future<void> _saveVectorStore(Map<String, Map<String, dynamic>> store) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(store);
    await prefs.setString(_vectorStoreKey, jsonString);
  }

  // 添加日记内容及其向量
  static Future<void> addEntry(String date, String content) async {
    final List<double>? vector = await EmbeddingService.getEmbedding(content);
    if (vector == null || vector.isEmpty) {
      return;
    }
    final Map<String, Map<String, dynamic>> store = await _loadVectorStore();

    store[date] = {
      'content': content,
      'vector': vector,
    };
    await _saveVectorStore(store);
  }

  // 兼容外部调用：索引日记到向量库
  static Future<void> indexDiary(String date, String content) async {
    await addEntry(date, content);
  }

  // 移除日记内容及其向量
  static Future<void> removeEntry(String date) async {
    final Map<String, Map<String, dynamic>> store = await _loadVectorStore();
    if (store.containsKey(date)) {
      store.remove(date);
      await _saveVectorStore(store);
    }
  }

  // 搜索相似日记
  // 返回 List<MapEntry<String, double>>，key是日期，value是相似度
  static Future<List<MapEntry<String, double>>> search(String query, {int topK = 3}) async {
    final List<double>? queryVector = await EmbeddingService.getEmbedding(query);
    final Map<String, Map<String, dynamic>> store = await _loadVectorStore();

    if (store.isEmpty || queryVector == null || queryVector.isEmpty) {
      return [];
    }

    final List<MapEntry<String, double>> similarities = [];
    store.forEach((date, data) {
      final List<dynamic>? vectorDynamic = data['vector'];
      if (vectorDynamic != null) {
        final List<double> entryVector = vectorDynamic.cast<double>();
        final double similarity = _cosineSimilarity(queryVector, entryVector);
        similarities.add(MapEntry(date, similarity));
      }
    });

    similarities.sort((a, b) => b.value.compareTo(a.value)); // 降序排列
    return similarities.take(topK).toList();
  }

  // 计算余弦相似度
  static double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.isEmpty || vec2.isEmpty || vec1.length != vec2.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      magnitude1 += vec1[i] * vec1[i];
      magnitude2 += vec2[i] * vec2[i];
    }

    magnitude1 = _sqrt(magnitude1);
    magnitude2 = _sqrt(magnitude2);

    if (magnitude1 == 0 || magnitude2 == 0) {
      return 0.0;
    }

    return dotProduct / (magnitude1 * magnitude2);
  }

  // 自定义 sqrt 函数，因为 dart:math 引入后在 Flutter web 上可能有问题
  static double _sqrt(double x) {
    if (x < 0) throw ArgumentError('Square root of negative number');
    if (x == 0) return 0;
    double guess = x / 2.0;
    for (int i = 0; i < 10; i++) { // 迭代10次足以获得足够精度
      guess = (guess + x / guess) / 2.0;
    }
    return guess;
  }
}
