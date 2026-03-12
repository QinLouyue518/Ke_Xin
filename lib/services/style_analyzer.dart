import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/literary_fingerprint.dart';
import 'api_settings_service.dart';

class StyleAnalyzer {
  static const String _storageKey = 'user_literary_fingerprint';

  // 加载本地指纹
  static Future<LiteraryFingerprint> loadFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        return LiteraryFingerprint.fromJson(jsonDecode(jsonString));
      } catch (e) {
        return LiteraryFingerprint.empty();
      }
    }
    return LiteraryFingerprint.empty();
  }

  // 保存指纹
  static Future<void> saveFingerprint(LiteraryFingerprint fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(fingerprint.toJson()));
  }

  // 分析日记生成指纹
  static Future<LiteraryFingerprint?> analyzeStyle(List<String> diarySamples) async {
    if (diarySamples.isEmpty) return null;

    // 从自定义配置读取 API 信息
    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();

    // 如果未配置 API Key，返回 null
    if (apiKey.isEmpty) {
      return null;
    }

    // 拼接日记样本
    String samplesText = diarySamples.map((s) => "【样本】\n$s").join("\n\n");
    if (samplesText.length > 6000) {
      samplesText = samplesText.substring(0, 6000) + "...(截断)";
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": modelName,
          "messages": [
            {
              "role": "system",
              "content": """
你是一位专业的文学风格分析师和语言学家。请深入研读用户的日记样本，挖掘文字背后的灵魂，生成一份极度精细的“创作者快照”。
请严格按照以下 JSON 格式输出，不要包含 markdown 标记或其他废话。

需要分析的维度（包括 Phase 2 新增的深层心理维度）：
1. **核心定位**：一句话总结作者的写作引擎（如：细腻自省、理性反思）。
2. **定量分析**：
   - 代词倾向：统计“我们”、“你”、“他”的使用比例和倾向。
   - 句速与节奏：估算逗号与句号的使用比（长句多还是短句多）。
   - 修辞密度：每百字中隐喻、术语、设问的出现频率。
   - 结构特征：常用的句末语气词（如“呢”、“吧”），常用的连接词（对比、因果）。
3. **定性描述**：
   - 节奏与句型：长短句交替的规律。
   - 互动口吻：是独白式，还是对话式？
4. **【重点】深层心理与文学特征**：
   - **叙事模式**：是完全沉浸在当下的情绪（沉浸式），还是站在远处审视自己（抽离式）？或者是两者的某种混合？
   - **情绪基调**：底色是悲观虚无、热烈激昂、克制隐忍，还是焦虑不安？
   - **思维模式**：是线性逻辑推进，还是高频的跳跃联想？是否喜欢从日常琐事上升到哲学思考（元认知）？
   - **词汇偏好**：是否反复使用某些特定意象（如深海、光、雨、镜子）？或者偏好某些领域的术语（心理学、科技）？

JSON 输出格式：
{
  "core_identity": "...",
  "primary_directions": ["主方向1", "主方向2"],
  "secondary_directions": ["次方向1", "次方向2"],
  "pronoun_tendency": "描述代词使用习惯...",
  "sentence_rhythm": "描述句长和标点习惯...",
  "rhetoric_density": "描述修辞使用频率...",
  "interaction_frequency": "描述互动感...",
  "structural_features": "描述功能词习惯...",
  "rhythm_description": "详细描述节奏感...",
  "rhetoric_description": "详细描述修辞风格...",
  "narrative_logic": "描述篇章推进逻辑...",
  "tone_description": "描述口吻和语感...",
  
  "narrative_mode": "描述叙事视角（沉浸/抽离/混合）...",
  "emotional_tone": "描述情绪底色（虚无/热烈/克制...）...",
  "meta_cognition": "描述思维跳跃度与元认知...",
  "vocabulary_preference": "描述高频意象或术语偏好..."
}
"""
            },
            {
              "role": "user",
              "content": "请基于以下日记样本进行深度风格分析：\n\n$samplesText"
            }
          ],
          "temperature": 0.3, // 低温，保证分析的客观准确性
          "response_format": {"type": "json_object"}
        }),
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String? content = data['choices']?[0]?['message']?['content'];
        if (content != null) {
          final fp = LiteraryFingerprint.fromJson(jsonDecode(content));
          await saveFingerprint(fp); // 自动保存
          return fp;
        }
      }
    } catch (e) {
      print("风格分析失败: $e");
    }
    return null;
  }
}

