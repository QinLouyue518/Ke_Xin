import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/vector_store_service.dart';
class WriteDiaryPage extends StatefulWidget {
  final Map<String, String>? existingEntry;

  const WriteDiaryPage({super.key, this.existingEntry});

  @override
  State<WriteDiaryPage> createState() => _WriteDiaryPageState();
}

class _WriteDiaryPageState extends State<WriteDiaryPage> {
  final TextEditingController _textEditingController = TextEditingController();
  bool _isAnalyzing = false;
  
  // 📅 新增：用来存当前选择的日期
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // ✅ 初始化日期逻辑
    if (widget.existingEntry != null && widget.existingEntry!['date'] != null) {
      // 如果是编辑旧日记，解析旧日期
      try {
        _selectedDate = DateTime.parse(widget.existingEntry!['date']!);
      } catch (e) {
        _selectedDate = DateTime.now(); // 解析失败就默认今天
      }
      _textEditingController.text = widget.existingEntry!['content'] ?? '';
    } else {
      // 如果是新日记，默认今天
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  // 📅 弹出日历选择器
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // 允许补写到 2000 年
      lastDate: DateTime.now(),  // 不能写未来的日记
      // 设置日历的主题色，配合你的莫兰迪蓝
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor, 
              onPrimary: Colors.white, 
              onSurface: Colors.black, 
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // AI 分析函数 (保持不变)
  Future<Map<String, dynamic>> analyzeMood(String text) async {
    final apiKey = dotenv.env['API_KEY'] ?? ''; 
    final apiUrl = dotenv.env['API_URL'] ?? 'https://api.siliconflow.cn/v1/chat/completions';

    if (apiKey.isEmpty || apiKey.startsWith('sk-xxxx')) return _getLocalFallback(text);

    // ✨ 1. 升级版“记忆涟漪”：使用向量检索寻找最相似的过往日记
    String pastDiariesContext = "";
    try {
      final results = await VectorStoreService.search(text, topK: 3); // 找最相似的3篇
      if (results.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final String? jsonString = prefs.getString('diary_data');
        if (jsonString != null) {
          List<dynamic> allDiaries = jsonDecode(jsonString);
          final DateTime cutoffDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

          StringBuffer sb = StringBuffer();
          sb.writeln("【过往记忆库 (AI 检索到的相似回忆)】");
          
          for (var res in results) {
            // 找到原日记内容
            var match = allDiaries.firstWhere((d) => d['date'] == res.key, orElse: () => null);
            if (match != null) {
              DateTime itemDate = DateTime.parse(match['date']);
              // 依然只允许“回顾过去”，不许“预知未来”（防止检索到比当前选定日期更晚的日记）
              if (itemDate.isBefore(cutoffDate)) {
                 String content = match['content'].toString();
                 String summary = content.length > 80 ? "${content.substring(0, 80)}..." : content;
                 sb.writeln("[ID: ${match['date']}] 内容摘要：$summary (相似度: ${(res.value * 100).toStringAsFixed(0)}%)");
              }
            }
          }
          pastDiariesContext = sb.toString();
        }
      }
    } catch (e) {
      debugPrint("Error preparing vector memory ripple: $e");
    }

    try {
      final systemPrompt = '''
你是一个专业的心理咨询师。请分析用户日记。
**必须且只能**返回纯 JSON 格式数据，**严禁**包含 markdown 标记（如 ```json ... ```）。

【任务 1：情绪分析】
返回格式如下：
{
  "emoji": "最匹配的表情(1个)",
  "mood_keyword": "情绪关键词(2-4字)",
  "score": "情绪能量打分(0-100整数)",
  "comment": "暖心简评(20字内)",
  "advice": "一条具体的行动建议(15字内)",
  "quote": "一句契合当下心境的文艺金句",
  "reflection_question": "一个直击灵魂的反思问题（30字内），引导用户觉察日记背后的深层情绪或思维模式。",
  "related_date": "如果【过往记忆库】中有一篇日记与今天的内容有**强关联**（因果、对比、重复），请填入那个 [ID] 里的日期字符串。如果没有强关联，请返回 null 或空字符串。",
  "related_reason": "一句话解释为什么关联这两篇日记（例如：'去年的今天你也在这个问题上纠结，但你看，你已经跨过去了。'）"
}

【任务 2：寻找记忆涟漪】
以下是 AI 通过语义检索找到的、与今天日记**心境或事件最相似**的几篇过往日记：
$pastDiariesContext

请仔细比对，判断今天的新日记与其中某篇旧日记是否存在**深层的呼应**？
- 例如：同样的困境再次出现、当年的愿望终于实现、或者是心态发生了截然不同的变化。
- **如果有强关联**，请在 JSON 返回中增加字段 "related_date" 和 "related_reason"。
- **如果没有**（检索结果虽然相似但没有深层联系），请留空。
''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "deepseek-chat", // 或者 deepseek-ai/DeepSeek-V3
          "messages": [
            {
              "role": "system",
              "content": systemPrompt,
            },
            {
              "role": "user", 
              "content": text,
            }
          ],
          "temperature": 0.3, 
        }),
      ).timeout(const Duration(seconds: 30)); // 30秒超时

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        String? content = data['choices']?[0]?['message']?['content'];

        if (content != null) {
          content = content.replaceAll('```json', '').replaceAll('```', '').trim();
          final startIndex = content.indexOf('{');
          final endIndex = content.lastIndexOf('}');
          if (startIndex != -1 && endIndex != -1) {
            content = content.substring(startIndex, endIndex + 1);
          }

          try {
            return jsonDecode(content);
          } catch (e) {
            debugPrint("Error: 清洗后的内容 JSON 解析失败: $e");
            debugPrint("Error: 尝试解析的内容是: $content");
          }
        }
      } else {
        debugPrint('Error: API 请求失败，状态码: ${response.statusCode}, 响应体: ${response.body}');
      }
      return _getLocalFallback(text);
    } catch (e) {
      debugPrint('Fatal Error: 发生异常: $e');
      return _getLocalFallback(text);
    }
  }

  Map<String, dynamic> _getLocalFallback(String text) {
    return {
      "emoji": "😐", "mood_keyword": "平静", "score": 50,
      "comment": "记录生活，留住当下。", "advice": "喝杯水，休息一下。",
      "quote": "平平淡淡才是真。",
      "reflection_question": "这件事给你带来了什么启示？"
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? '修改日记' : '写日记'),
        actions: [
          // 📅 在右上角加一个日历图标，点击也能改日期
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
            tooltip: "修改日期",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ✨✨✨ 新增：日期选择条 ✨✨✨
            InkWell(
              onTap: _pickDate, // 点击整行都能选日期
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_note, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 10),
                    const Text("日期：", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDate), // 显示当前选择的日期
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // 输入框
            Expanded(
              child: TextField(
                controller: _textEditingController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '写下那天的回忆...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            
            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
             child: ElevatedButton(
                onPressed: _isAnalyzing
                    ? null
                    : () async {
                        final String diaryContent = _textEditingController.text.trim();
                        
                        if (diaryContent.isNotEmpty) {
                          setState(() {
                            _isAnalyzing = true;
                          });

                          Map<String, dynamic> aiResult; 
                          
                          try {
                            aiResult = await analyzeMood(diaryContent);
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isAnalyzing = false;
                              });
                            }
                          }

                          if (mounted) {
                            // 👇👇👇 核心修改在这里！👇👇👇
                            // 不管用户选的日期是什么，都把它格式化成 "yyyy-MM-dd"
                            String dateToSave = DateFormat('yyyy-MM-dd').format(_selectedDate);

                            final newEntry = {
                              'date': dateToSave, // ✅ 使用标准格式的日期
                              'content': diaryContent,
                              'emoji': aiResult['emoji']?.toString() ?? '😐',
                              'mood_keyword': aiResult['mood_keyword']?.toString() ?? '',
                              'score': aiResult['score']?.toString() ?? '50',
                              'comment': aiResult['comment']?.toString() ?? '',
                              'advice': aiResult['advice']?.toString() ?? '',
                              'quote': aiResult['quote']?.toString() ?? '',
                              'question': aiResult['reflection_question']?.toString() ?? '', // 苏格拉底式提问
                              'related_date': aiResult['related_date']?.toString() ?? '', // 记忆涟漪日期
                              'related_reason': aiResult['related_reason']?.toString() ?? '', // 记忆涟漪理由
                            };
                            
                            Navigator.pop(context, newEntry);
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                // ... child 部分保持不变 ...
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isAnalyzing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text("AI 正在重温回忆..."),
                        ],
                      )
                    : const Text('保 存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}