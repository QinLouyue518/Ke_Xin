import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../services/api_settings_service.dart'; // ✨ 引入 API 配置服务

import '../models/chronicle_chapter.dart';
import '../models/literary_fingerprint.dart';
import '../services/style_analyzer.dart';
import '../services/vector_store_service.dart'; // ✨ 引入向量服务

// 书籍元数据模型
class ChronicleBook {
  String title;
  String author;
  String coverColorHex; // Hex color string, e.g., "#FF5733"

  ChronicleBook({
    this.title = "流年史",
    this.author = "佚名",
    this.coverColorHex = "#607D8B", // 默认蓝灰色
  });

  factory ChronicleBook.fromJson(Map<String, dynamic> json) {
    return ChronicleBook(
      title: json['title'] ?? "流年史",
      author: json['author'] ?? "佚名",
      coverColorHex: json['cover_color'] ?? "#607D8B",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'cover_color': coverColorHex,
    };
  }
}

// 纸张质感颜色
const Color kPaperColor = Color(0xFFFDFBF7); // 米白纸张
const Color kInkColor = Color(0xFF2D2D2D); // 墨色
const Color kSealColor = Color(0xFFB71C1C); // 朱砂印泥
const Color kAccentColor = Color(0xFF455A64); // 黛蓝

class ChroniclePage extends StatefulWidget {
  const ChroniclePage({super.key});

  @override
  State<ChroniclePage> createState() => _ChroniclePageState();
}

class _ChroniclePageState extends State<ChroniclePage> {
  List<ChronicleChapter> _chapters = [];
  LiteraryFingerprint _fingerprint = LiteraryFingerprint.empty();
  ChronicleBook _bookInfo = ChronicleBook(); // 书籍信息
  bool _isLoading = false;
  bool _isAnalyzing = false; // 是否正在分析风格

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 加载书籍信息
    final String? bookJson = prefs.getString('chronicle_book_info');
    if (bookJson != null) {
      _bookInfo = ChronicleBook.fromJson(jsonDecode(bookJson));
    }

    // 加载章节
    final String? chaptersJson = prefs.getString('chronicle_chapters');
    if (chaptersJson != null) {
      final List<dynamic> list = jsonDecode(chaptersJson);
      setState(() {
        _chapters = list.map((e) => ChronicleChapter.fromJson(e)).toList();
        // 按序号排序
        _chapters.sort((a, b) => a.order.compareTo(b.order));
      });
    }

    // 加载指纹
    final fp = await StyleAnalyzer.loadFingerprint();
    setState(() {
      _fingerprint = fp;
    });
  }

  Future<void> _saveBookInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chronicle_book_info', jsonEncode(_bookInfo.toJson()));
  }

  Future<void> _saveChapters() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_chapters.map((e) => e.toJson()).toList());
    await prefs.setString('chronicle_chapters', jsonString);
  }

  // 分析风格流程
  Future<void> _analyzeStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final String? diaryJson = prefs.getString('diary_data');
    if (diaryJson == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("日记太少，无法进行风格侧写")));
      return;
    }

    List<dynamic> diaries = jsonDecode(diaryJson);
    if (diaries.length < 5) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("至少需要5篇日记才能准确捕捉您的文风")));
      return;
    }

    setState(() { _isAnalyzing = true; });

    // 取最近的 20 篇作为样本
    List<String> samples = diaries.take(20).map((e) => e['content'] as String).toList();
    final newFp = await StyleAnalyzer.analyzeStyle(samples);

    if (!mounted) return; // ✨ 修复：检查组件是否存活

    if (newFp != null) {
      setState(() {
        _fingerprint = newFp;
      });
      _showFingerprintDialog(newFp);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("分析失败，请检查网络")));
    }

    if (mounted) {
      setState(() { _isAnalyzing = false; });
    }
  }

  // Phase 3: 基于已定稿的传记章节，优化文学指纹
  // 这通常比分析日记更准确，因为传记章节是用户认可(或修改过)的最终成品
  Future<void> _refineStyleFromChapters() async {
    final finalizedChapters = _chapters.where((c) => c.isFinalized).toList();
    if (finalizedChapters.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("还没有定稿的章节可供学习")));
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("优化文学指纹"),
        content: Text("将基于您已定稿的 ${finalizedChapters.length} 章传记，重新提炼写作风格。这能让 AI 更懂您的笔触。\n\n建议在您手动润色过几章内容后再执行此操作。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("开始优化")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() { _isAnalyzing = true; });

    // 提取章节内容作为样本
    List<String> samples = finalizedChapters.map((c) => c.content).toList();
    
    // 如果样本太少，补充一些日记
    if (samples.length < 3) {
      final prefs = await SharedPreferences.getInstance();
      final String? diaryJson = prefs.getString('diary_data');
      if (diaryJson != null) {
        List<dynamic> diaries = jsonDecode(diaryJson);
        samples.addAll(diaries.take(5).map((e) => e['content'] as String));
      }
    }

    final newFp = await StyleAnalyzer.analyzeStyle(samples);

    if (!mounted) return;

    if (newFp != null) {
      setState(() {
        _fingerprint = newFp;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("指纹优化完成！AI 已通过阅读您的作品完成了进化。")));
      _showFingerprintDialog(newFp); // 展示新指纹
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("优化失败，请稍后重试")));
    }

    setState(() { _isAnalyzing = false; });
  }

  // 展示风格指纹弹窗
  void _showFingerprintDialog(LiteraryFingerprint fp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("您的文学指纹"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("核心定位：\n${fp.coreIdentity}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Divider(),
              
              // 基础特征
              _buildFingerprintItem("句法节奏", fp.sentenceRhythm),
              _buildFingerprintItem("代词倾向", fp.pronounTendency),
              _buildFingerprintItem("修辞习惯", fp.rhetoricDensity),

              const Divider(),
              const Text("深层心理特征 (Phase 2)", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 高级特征
              _buildFingerprintItem("叙事视角", fp.narrativeMode.isEmpty ? "待分析" : fp.narrativeMode),
              _buildFingerprintItem("情绪底色", fp.emotionalTone.isEmpty ? "待分析" : fp.emotionalTone),
              _buildFingerprintItem("思维模式", fp.metaCognition.isEmpty ? "待分析" : fp.metaCognition),
              _buildFingerprintItem("词汇偏好", fp.vocabularyPreference.isEmpty ? "待分析" : fp.vocabularyPreference),

              const SizedBox(height: 10),
              const Text("AI 史官已就位，准备好为您立传。", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          if (_chapters.any((c) => c.isFinalized))
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 关掉弹窗
                _refineStyleFromChapters();
              }, 
              child: const Text("基于已成书章节微调指纹")
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("太棒了"))
        ],
      ),
    );
  }

  Widget _buildFingerprintItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: "$label：", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // 提取并总结聊天上下文
  Future<String> _summarizeChatContext(List<Map<String, String>> diaries) async {
    final StringBuffer chatBuffer = StringBuffer();
    bool hasChat = false;

    for (var diary in diaries) {
      if (diary['chat_history'] != null && diary['chat_history']!.isNotEmpty) {
        try {
          final List<dynamic> history = jsonDecode(diary['chat_history']!);
          if (history.isNotEmpty) {
            hasChat = true;
            chatBuffer.writeln("【${diary['date']} 的对话记录】");
            // 只取最近的 20 条，且忽略 system 消息
            final relevantMsgs = history.where((m) => m['role'] != 'system').take(20);
            for (var msg in relevantMsgs) {
              // 截断单条消息长度，防止过长
              String content = msg['content'].toString();
              if (content.length > 100) content = "${content.substring(0, 100)}...";
              chatBuffer.writeln("${msg['role'] == 'user' ? '我' : 'AI'}: $content");
            }
            chatBuffer.writeln();
          }
        } catch (e) {
          // ignore parsing error
        }
      }
    }

    if (!hasChat) return "";

    // 调用 AI 进行总结
    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();

    if (apiKey.isEmpty) return "";

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
              "content": "你是一个助手，负责从用户的日记聊天记录中提取“潜台词”和“背景信息”。\n请忽略闲聊和打招呼，重点提取：\n1. 导致情绪变化的具体事件（起因）。\n2. 用户未在日记中明说的真实想法或纠结。\n3. 涉及的人名、地名等事实背景。\n请输出一段约 150 字的【背景注解】，供传记作家参考。"
            },
            {
              "role": "user",
              "content": chatBuffer.toString()
            }
          ],
          "temperature": 0.5,
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices']?[0]?['message']?['content'] ?? "";
      }
    } catch (e) {
      debugPrint("Error summarizing chat: $e");
    }
    return "";
  }

  // 生成新章节
  Future<void> _generateNewChapter(DateTime start, DateTime end) async {
    // 1. 检查是否有风格指纹
    if (_fingerprint.isEmpty) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("未检测到文学指纹"),
          content: const Text("为了让传记更像您亲笔所写，建议先让 AI 分析您的过往日记风格。是否立即分析？"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("暂不，直接写")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("开始分析")),
          ],
        ),
      );
      if (confirm == true) {
        await _analyzeStyle();
        if (_fingerprint.isEmpty) return; // 分析失败或中断
      }
    }

    setState(() { _isLoading = true; });

    try {
      // 2. 准备素材
      final prefs = await SharedPreferences.getInstance();
      final String? diaryJson = prefs.getString('diary_data');
      if (diaryJson == null) throw Exception("没有日记数据");

      List<dynamic> allDiaries = jsonDecode(diaryJson);
      // 筛选日期范围内的日记 (注意 diary_data 是倒序的，要处理一下)
      List<Map<String, String>> rangeDiaries = [];
      for (var d in allDiaries) {
        DateTime date = DateTime.parse(d['date']);
        // 简单的日期比较，忽略时分秒
        DateTime dOnly = DateTime(date.year, date.month, date.day);
        DateTime sOnly = DateTime(start.year, start.month, start.day);
        DateTime eOnly = DateTime(end.year, end.month, end.day);
        
        if (!dOnly.isBefore(sOnly) && !dOnly.isAfter(eOnly)) {
          rangeDiaries.add(Map<String, String>.from(d));
        }
      }
      
      // 按时间正序排列，方便 AI 理解时间线
      rangeDiaries.sort((a, b) => a['date']!.compareTo(b['date']!));

      if (rangeDiaries.isEmpty) {
        throw Exception("所选时间段内没有日记");
      }

      String diaryContext = rangeDiaries.map((e) => "【${e['date']}】${e['content']}").join("\n\n");

      // ✨✨✨ 3.0 深度素材挖掘 (基于向量检索) ✨✨✨
      // 逻辑：提取这段日记里的高频关键词，去全量数据库里搜“前情提要”
      // 简单起见，我们直接用 rangeDiaries 里最长的一篇作为 Query 去搜（或者拼接前300字）
      String ragContext = "";
      try {
        String queryText = diaryContext.length > 500 ? diaryContext.substring(0, 500) : diaryContext;
        // 🔍 V2.5 升级：增加日期过滤和相似度阈值
        final results = await VectorStoreService.search(
          queryText, 
          topK: 5
        );
        
        if (results.isNotEmpty) {
           final DateTime startDateObj = start;
           StringBuffer sb = StringBuffer();
           
           List<dynamic> allDiariesData = allDiaries; 
           
           for (var res in results) {
             bool isInRange = rangeDiaries.any((d) => d['date'] == res.key);
             if (!isInRange) {
                var match = allDiariesData.firstWhere((d) => d['date'] == res.key, orElse: () => null);
                if (match != null) {
                  DateTime itemDate = DateTime.parse(match['date']);
                  if (itemDate.isBefore(startDateObj)) {
                    String content = match['content'].toString();
                    if (content.length > 100) content = content.substring(0, 100) + "...";
                    sb.writeln(">> [${match['date']}] $content");
                  }
                }
             }
           }
           ragContext = sb.toString();
        }
      } catch (e) {
        debugPrint("Chronicle RAG error: $e");
      }

      // 3.1 提取聊天记录背景 (Phase 1 优化)
      String chatContext = "";
      setState(() { _isAnalyzing = true; }); // 借用一下 loading 状态显示
      try {
        chatContext = await _summarizeChatContext(rangeDiaries);
      } catch (e) {
        debugPrint("Chat summary failed: $e");
      }

      // 3.2 准备上一章上下文 (如果有)
      String prevContext = "";
      if (_chapters.isNotEmpty) {
        final lastChapter = _chapters.last;
        prevContext = "上一章摘要：${lastChapter.summary}\n上一章结尾：${lastChapter.content.length > 200 ? lastChapter.content.substring(lastChapter.content.length - 200) : lastChapter.content}";
      }

      // 4. 构建超级 Prompt (Phase 4 升级：先生成大纲)
      await _generateOutline(start, end, diaryContext, chatContext, prevContext, ragContext);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("生成失败: $e")));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // Phase 4: 生成大纲（大纲 + 提问双重模式）
  Future<void> _generateOutline(DateTime start, DateTime end, String diaryContext, String chatContext, String prevContext, String ragContext) async {
    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();

    if (apiKey.isEmpty) {
      _showConfigRequiredDialog();
      setState(() { _isLoading = false; });
      return;
    }

    String ragPromptBlock = "";
    if (ragContext.isNotEmpty) {
      ragPromptBlock = """
【历史伏笔 (关联的往事)】：
为了让传记更具厚度，我们检索到了以下往事，可能与本章内容存在草蛇灰线的联系（如：伏笔回收、宿命感）。请在构思时酌情参考：
$ragContext
""";
    }

    final outlinePrompt = """
你是一位严谨的传记作家助手。在正式撰写新章节前，你需要完成两件事：
1. **拟定大纲**：根据日记素材，规划本章的核心情绪、情节和策略。
2. **深度访谈（至关重要）**：
   由于用户的日记可能偏向“意识流”，缺乏具体的情节支撑。你需要扮演一位打破砂锅问到底的记者，**提出 4-6 个具体问题**，尽可能还原事实真相。
   
   **必须包含以下维度：**
   - **指代消歧（高优先级）**：如果日记中频繁使用“他/她/你”等代词且指代不明，**必须**专门提问确认其身份。（例如：“日记里一直出现的‘她’是指您的恋人还是母亲？”）
   - **事实还原（重中之重）**：日记中提到的某个人是谁？某件事的具体起因和结果是什么？当时在什么地点？（例如：“日记里提到的‘那场灾难’具体是指什么事？”）
   - **人物关系**：提到的人物与作者是什么关系？之前的相处模式是怎样的？
   - **心理动机**：当时做某个决定时，内心深处真实的动机是什么？
   - **细节填充**：当时的环境、天气、或者某个具体的动作细节是怎样的？

【现有素材】：
- 日记原文：(略)
- 背景注解：$chatContext

$ragPromptBlock

【输出格式 JSON】：
{
  "core_emotion": "本章的总体基调（如：迷茫、喜悦）",
  "key_events": ["事件1", "事件2"],
  "narrative_strategy": "叙事手法（如：双线叙事、意识流）",
  "keywords": ["关键词1", "关键词2"],
  "questions": [
    "问题1：[指代] 日记中反复提到的那个‘他’，具体指的是谁？这对理解您的情绪很重要。",
    "问题2：[事实] 日记中提到的“那个决定”具体是指什么？是辞职还是分手？",
    "问题3：[人物] “老K”是您的同事还是朋友？你们之间之前发生过什么矛盾吗？",
    "问题4：[心理] 当时您为什么选择沉默？是出于恐惧还是不屑？",
    "问题5：..."
  ]
}
""";

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
            {"role": "system", "content": outlinePrompt},
            {"role": "user", "content": "【本章素材】\n$diaryContext"}
          ],
          "temperature": 0.5,
          "response_format": {"type": "json_object"},
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(minutes: 1));

      if (response.statusCode == 200 && mounted) {
         final data = jsonDecode(utf8.decode(response.bodyBytes));
         final content = data['choices']?[0]?['message']?['content'];
         if (content != null) {
           final outline = jsonDecode(content);
           _showOutlineDialog(start, end, diaryContext, chatContext, prevContext, ragContext, outline);
         }
      }
    } catch (e) {
      debugPrint("Outline generation failed: $e");
      // Fallback: 如果大纲生成失败，直接生成正文（降级处理）
      _generateContentFromOutlineAndInterview(start, end, diaryContext, chatContext, prevContext, ragContext, null, "");
    }
  }

  // Phase 4: 展示构思与访谈对话框
  void _showOutlineDialog(DateTime start, DateTime end, String diaryContext, String chatContext, String prevContext, String ragContext, Map<String, dynamic> outline) {
    // 1. 大纲控制器
    final emotionCtrl = TextEditingController(text: outline['core_emotion']);
    final strategyCtrl = TextEditingController(text: outline['narrative_strategy']);
    final keywordsCtrl = TextEditingController(text: (outline['keywords'] as List).join("、"));
    final eventsCtrl = TextEditingController(text: (outline['key_events'] as List).join("\n"));

    // 2. 访谈控制器
    final List<String> questions = List<String>.from(outline['questions'] ?? []);
    final List<TextEditingController> answerControllers = questions.map((_) => TextEditingController()).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text("构思与访谈", style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, color: Colors.black87)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 第一部分：大纲 ---
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted, size: 16, color: kAccentColor),
                      SizedBox(width: 8),
                      Text("创作大纲 (可修改)", style: TextStyle(fontWeight: FontWeight.bold, color: kAccentColor)),
                    ],
                  ),
                ),
                TextField(
                  controller: emotionCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(labelText: "核心情绪", isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: eventsCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(labelText: "核心事件 / 故事梗概", isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: strategyCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(labelText: "叙事策略", isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keywordsCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(labelText: "关键词", isDense: true, border: OutlineInputBorder()),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // --- 第二部分：访谈 ---
                if (questions.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.question_answer_outlined, size: 16, color: kAccentColor),
                        SizedBox(width: 8),
                        Text("细节访谈 (请回答)", style: TextStyle(fontWeight: FontWeight.bold, color: kAccentColor)),
                      ],
                    ),
                  ),
                  ...List.generate(questions.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Q${index + 1}: ${questions[index]}",
                            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: answerControllers[index],
                            maxLines: 2,
                            minLines: 1,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "您的回答...",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              fillColor: Colors.grey[50],
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _isLoading = false; });
            }, 
            child: const Text("取消", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kInkColor,
              foregroundColor: kPaperColor,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              
              // 1. 收集大纲修改
              final newOutline = {
                "core_emotion": emotionCtrl.text,
                "key_events": eventsCtrl.text.split('\n').where((s) => s.isNotEmpty).toList(),
                "narrative_strategy": strategyCtrl.text,
                "keywords": keywordsCtrl.text.split('、'),
              };

              // 2. 收集访谈回答
              StringBuffer interviewResult = StringBuffer();
              for (int i = 0; i < questions.length; i++) {
                if (answerControllers[i].text.trim().isNotEmpty) {
                  interviewResult.writeln("Q: ${questions[i]}");
                  interviewResult.writeln("A: ${answerControllers[i].text}");
                  interviewResult.writeln("---");
                }
              }

              // 3. 生成正文
              _generateContentFromOutlineAndInterview(start, end, diaryContext, chatContext, prevContext, ragContext, newOutline, interviewResult.toString());
            }, 
            child: const Text("定稿 · 落笔", style: TextStyle(fontFamily: 'Serif')) 
          ),
        ],
      ),
    );
  }

  // Phase 4: 终极生成逻辑
  Future<void> _generateContentFromOutlineAndInterview(
    DateTime start, 
    DateTime end, 
    String diaryContext, 
    String chatContext, 
    String prevContext,
    String ragContext, // ✨ 新增
    Map<String, dynamic>? outline, 
    String interviewResult
  ) async {
    // 重新进入 loading 状态
    setState(() { _isLoading = true; });

    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();
    
    if (apiKey.isEmpty) {
      _showConfigRequiredDialog();
      setState(() { _isLoading = false; });
      return;
    }
    
    // 构造大纲指令
    String outlineInstruction = "";
    if (outline != null) {
      outlineInstruction = """
【大纲约束】：
- 核心情绪：${outline['core_emotion']}
- 核心事件：${(outline['key_events'] as List).join('；')}
- 叙事策略：${outline['narrative_strategy']}
- 关键词：${(outline['keywords'] as List).join('、')}
""";
    }

    // 构造访谈指令
    String interviewInstruction = "";
    if (interviewResult.isNotEmpty) {
      interviewInstruction = """
【作者访谈录 (最高优先级)】：
以下是作者对细节的补充和澄清，请务必采纳：
$interviewResult
""";
    }

    // 构造 RAG 指令
    String ragInstruction = "";
    if (ragContext.isNotEmpty) {
      ragInstruction = """
【历史伏笔 (AI 检索的关联记忆)】：
以下是作者在其他时期写下的日记，可能包含本章事件的起因或伏笔。请尝试将其自然地融入叙事（例如：作为闪回、对比或潜意识）：
$ragContext
""";
    }

    final systemPrompt = """
你是一位获得过诺贝尔文学奖的传记作家，擅长第一人称小说化叙事。你需要基于用户的日记素材，创作《流年史》的新章节。

【核心指令】：
1. **文风复刻**：请严格模仿用户的“文学指纹”进行创作。
   - 核心基调：${_fingerprint.coreIdentity}
   - 句法节奏：${_fingerprint.sentenceRhythm}
   - 代词习惯：${_fingerprint.pronounTendency}
   - 修辞特征：${_fingerprint.rhetoricDescription}

$outlineInstruction

$interviewInstruction

$ragInstruction

2. **文学质感增强（关键）**：
   - **拒绝流水账**：不要写“我做了A，然后做了B”。请用**场景**推动叙事，让读者“看见”画面。
   - **通感描写**：请在文中至少植入 3 处**非视觉感官描写**（如：风的声音、衣服的触感、空气中特殊的味道）。
   - **环境隐喻**：用环境描写来投射人物内心。例如，不要直接写“我很伤心”，而要写“窗外的雨水在玻璃上蜿蜒，像一道道愈合不了的伤疤”。
   - **陌生化处理**：对常见的物体进行独特的比喻，避免陈词滥调。

3. **性格色彩**：
   - 采用“当时的我”视角，沉浸式还原当时的迷茫、冲动或喜悦。

【资料来源】：
- **日记原文**：用户当时的直接记录。
- **背景注解**：隐藏的事实真相。

【输出格式】：
请返回纯 JSON 格式：
{
  "title": "极具文学感的章节标题",
  "content": "正文内容（支持 Markdown，不少于 800 字）",
  "summary": "本章内容的简短摘要（用于生成下一章的记忆连接）"
}
""";

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
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": "【过往文脉】\n$prevContext\n\n【本章素材 - 日记原文】\n$diaryContext\n\n【本章素材 - 背景注解】\n$chatContext"}
          ],
          "temperature": 0.7,
          "response_format": {"type": "json_object"},
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(minutes: 3));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String? aiText = data['choices']?[0]?['message']?['content'];
        if (aiText != null) {
          final jsonRes = jsonDecode(aiText);
          final newChapter = ChronicleChapter(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: jsonRes['title'],
            content: jsonRes['content'],
            startDate: start,
            endDate: end,
            createdAt: DateTime.now(),
            summary: jsonRes['summary'],
            order: _chapters.length + 1,
          );

          setState(() {
            _chapters.add(newChapter);
          });
          await _saveChapters();
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => _ImmersiveChapterReaderPage(
              chapter: newChapter, 
              onSave: (updated) {
                setState(() {
                  int idx = _chapters.indexWhere((c) => c.id == updated.id);
                  if (idx != -1) _chapters[idx] = updated;
                });
                _saveChapters();
              },
              onDelete: (id) {
                setState(() {
                  _chapters.removeWhere((c) => c.id == id);
                });
                _saveChapters();
              }
            )));
          }
        }
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("生成失败: $e")));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // 日期范围选择器
  void _pickDateRange() async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: '开始立传',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      _generateNewChapter(result.start, result.end);
    }
  }

  // 编辑书籍信息
  void _editBookInfo() {
    final titleCtrl = TextEditingController(text: _bookInfo.title);
    final authorCtrl = TextEditingController(text: _bookInfo.author);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("修订书名"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: "书名", hintText: "给你的传记起个名字"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorCtrl,
              decoration: const InputDecoration(labelText: "作者署名"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _bookInfo.title = titleCtrl.text.isEmpty ? "流年史" : titleCtrl.text;
                _bookInfo.author = authorCtrl.text.isEmpty ? "佚名" : authorCtrl.text;
              });
              _saveBookInfo();
              Navigator.pop(context);
            },
            child: const Text("保存"),
          )
        ],
      ),
    );
  }

  void _showConfigRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要配置 API'),
        content: const Text(
          '检测到您尚未配置 API Key。\n为了保护您的 API 余额并允许自定义，请先配置您的 API 信息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/api-config');
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用应用主题色
    final primaryColor = Theme.of(context).primaryColor;
    final totalWords = _chapters.fold(0, (sum, c) => sum + c.content.length);

    return Scaffold(
      backgroundColor: Colors.white, // 回归现代纯白背景
      body: _isLoading 
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 24),
              Text(_isAnalyzing ? "正在品读..." : "正在落笔...", 
                style: TextStyle(color: primaryColor, letterSpacing: 1.2)),
            ],
          ))
        : CustomScrollView(
            slivers: [
              // 1. 现代大标题头部
              SliverAppBar.large(
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent, // 去掉滚动时的变色
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                    tooltip: "书名",
                    onPressed: _editBookInfo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.fingerprint, color: Colors.black54),
                    tooltip: "文心",
                    onPressed: _fingerprint.isEmpty ? _analyzeStyle : () => _showFingerprintDialog(_fingerprint),
                  )
                ],
                title: Text(
                  _bookInfo.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87), // 现代加粗无衬线
                ),
              ),

              // 2. 书籍信息摘要 (放在头部下方)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text("作者: ${_bookInfo.author}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                      const SizedBox(width: 10),
                      Text("·  共 ${_chapters.length} 卷  ·  $totalWords 字", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),

              // 3. 极简现代列表
              _chapters.isEmpty 
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_edu_outlined, size: 64, color: Colors.grey[200]),
                          const SizedBox(height: 16),
                          Text("暂无篇章", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: Icon(Icons.add, size: 18, color: primaryColor),
                            label: Text("写第一卷", style: TextStyle(color: primaryColor)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryColor.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _chapters.length) {
                             return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: _pickDateRange,
                                  icon: Icon(Icons.edit_note, size: 18, color: primaryColor),
                                  label: Text("续写新卷", style: TextStyle(color: primaryColor)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          final chapter = _chapters[index];
                          // 现代列表样式
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Hero(
                              tag: 'chapter_card_${chapter.id}',
                              flightShuttleBuilder: (
                                flightContext,
                                animation,
                                flightDirection,
                                fromHeroContext,
                                toHeroContext,
                              ) {
                                return Material(
                                  color: Colors.transparent,
                                  child: toHeroContext.widget,
                                );
                              },
                              child: Material(
                                color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    title: const Text("删除此卷"),
                                    content: Text("确定要删除「${chapter.title}」吗？\n删除后无法恢复。"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("取消", style: TextStyle(color: Colors.grey)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _chapters.removeWhere((c) => c.id == chapter.id);
                                          });
                                          _saveChapters();
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除")));
                                        },
                                        child: const Text("删除", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onTap: () {
                                    Navigator.push(context, PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                                        opacity: animation,
                                        child: _ImmersiveChapterReaderPage(
                                  chapter: chapter,
                                  onSave: (updated) {
                                    setState(() {
                                      int idx = _chapters.indexWhere((c) => c.id == updated.id);
                                      if (idx != -1) _chapters[idx] = updated;
                                    });
                                    _saveChapters();
                                  },
                                  onDelete: (id) {
                                    setState(() {
                                      _chapters.removeWhere((c) => c.id == id);
                                    });
                                    _saveChapters();
                                  },
                                        ),
                                      ),
                                      transitionDuration: const Duration(milliseconds: 500),
                                      reverseTransitionDuration: const Duration(milliseconds: 400),
                                    ));
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 序号
                                  Text(
                                    "${chapter.order}".padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 24, 
                                      fontWeight: FontWeight.bold, 
                                      color: Colors.grey[200], // 极淡的数字背景
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chapter.title,
                                          style: const TextStyle(
                                            fontSize: 17, 
                                            fontWeight: FontWeight.w600, // 半粗体
                                            color: Colors.black87,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              "${DateFormat('yyyy.MM.dd').format(chapter.startDate)} - ${DateFormat('yyyy.MM.dd').format(chapter.endDate)}",
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                            if (!chapter.isFinalized)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Container(
                                                  width: 6, height: 6, 
                                                  decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (chapter.summary.isNotEmpty)
                                          Text(
                                            chapter.summary,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
                        },
                        childCount: _chapters.length + 1,
                      ),
                    ),
                  ),
            ],
          ),
    );
  }
}

// ✨ 沉浸式阅读页面
class _ImmersiveChapterReaderPage extends StatefulWidget {
  final ChronicleChapter chapter;
  final Function(ChronicleChapter) onSave;
  final Function(String) onDelete;

  const _ImmersiveChapterReaderPage({
    required this.chapter,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_ImmersiveChapterReaderPage> createState() => _ImmersiveChapterReaderPageState();
}

class _ImmersiveChapterReaderPageState extends State<_ImmersiveChapterReaderPage> {
  // 核心状态
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isMenuVisible = true; // 默认进入时显示菜单，几秒后可自动隐藏
  bool _isEditing = false; // 是否处于编辑模式
  bool _isRewriting = false; // AI 状态

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chapter.title);
    _contentController = TextEditingController(text: widget.chapter.content);
    
    // 延迟自动隐藏菜单，让用户先看清界面
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isEditing) {
        setState(() => _isMenuVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 切换菜单显隐
  void _toggleMenu() {
    if (_isEditing) return; // 编辑模式下菜单常驻
    setState(() => _isMenuVisible = !_isMenuVisible);
  }

  // 保存变更
  void _saveChanges() {
    widget.onSave(widget.chapter.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      isFinalized: true,
    ));
  }

  // AI 润色逻辑 (复用原有逻辑)
  Future<void> _rewriteWithAI(String instruction) async {
    if (instruction.trim().isEmpty) return;
    setState(() { _isRewriting = true; });

    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();

    if (apiKey.isEmpty) {
      _showConfigRequiredDialog();
      setState(() { _isRewriting = false; });
      return;
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
              "content": "你是一个专业的文学编辑。请根据用户的【修改指令】，对【当前文本】进行润色、扩写或重写。\n请直接输出修改后的正文，不要包含任何解释性文字。"
            },
            {
              "role": "user",
              "content": "【当前文本】\n${_contentController.text}\n\n【修改指令】\n$instruction"
            }
          ],
          "temperature": 0.7,
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newContent = data['choices']?[0]?['message']?['content'];
        if (newContent != null) {
          setState(() {
            _contentController.text = newContent;
            _isEditing = true; // 自动进入编辑模式以便查看
            _isMenuVisible = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI 已完成润色")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("润色失败: $e")));
    } finally {
      if (mounted) setState(() { _isRewriting = false; });
    }
  }

  // 显示 AI 润色弹窗
  void _showRewriteDialog() {
    final instructionCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        title: const Row(children: [Icon(Icons.auto_fix_high, color: Colors.purple, size: 20), SizedBox(width: 8), Text("AI 润色")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _buildChip(instructionCtrl, "更细腻一点", "请把这段文字写得更细腻情感化一点"),
                _buildChip(instructionCtrl, "改成反讽语气", "把全文语气改成反讽和自嘲"),
                _buildChip(instructionCtrl, "增加环境描写", "在适当的地方增加环境描写，烘托氛围"),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: instructionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: "或者输入您的指令...", border: OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _rewriteWithAI(instructionCtrl.text);
            }, 
            child: const Text("开始润色")
          ),
        ],
      ),
    );
  }

  Widget _buildChip(TextEditingController ctrl, String label, String text) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => ctrl.text = text,
      backgroundColor: Colors.white,
      elevation: 1,
      side: BorderSide.none,
    );
  }

  void _showConfigRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要配置 API'),
        content: const Text(
          '检测到您尚未配置 API Key。\n为了保护您的 API 余额并允许自定义，请先配置您的 API 信息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/api-config');
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPaperColor, // 统一纸张背景
      body: Stack(
        children: [
          // 1. 底层：沉浸阅读内容
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu, // 点击任意位置切换菜单
              child: Hero(
                tag: 'chapter_card_${widget.chapter.id}',
                child: Material(
                  color: Colors.transparent, // 必须透明以显示 Scaffold 背景
                  child: SafeArea(
                    child: _isEditing ? _buildEditor() : _buildReader(),
                  ),
                ),
              ),
            ),
          ),

          // 2. 顶层：功能菜单 (AppBar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isMenuVisible || _isEditing ? 0 : -100, // 编辑模式下常驻
            left: 0, 
            right: 0,
            child: Container(
              color: kPaperColor.withOpacity(0.95), //由于是自定义AppBar，加一点背景
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
                          if (_isEditing) _saveChanges(); // 退出前保存
            Navigator.pop(context);
          },
        ),
                      const Spacer(),
                      if (_isRewriting)
                        const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple)))
                      else
          IconButton(
                          icon: const Icon(Icons.auto_fix_high, color: Colors.purple),
            tooltip: "AI 润色",
                          onPressed: _showRewriteDialog,
          ),
          IconButton(
                        icon: Icon(_isEditing ? Icons.check_circle : Icons.edit_outlined, 
                          color: _isEditing ? Colors.green : Colors.black87),
            tooltip: _isEditing ? "完成" : "编辑",
            onPressed: () {
                          if (_isEditing) _saveChanges();
                          setState(() => _isEditing = !_isEditing);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () {
              showDialog(
                context: context, 
                builder: (ctx) => AlertDialog(
                              title: const Text("删除此卷？"),
                  content: const Text("删除后无法恢复。"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
                    TextButton(onPressed: () {
                      widget.onDelete(widget.chapter.id);
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    }, child: const Text("删除", style: TextStyle(color: Colors.red))),
                  ],
                )
              );
            },
          ),
        ],
      ),
                ),
              ),
            ),
          ),

          // 3. 底部进度/信息栏 (阅读模式显示，编辑模式隐藏以免遮挡键盘)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            bottom: (_isMenuVisible && !_isEditing) ? 0 : -80,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kPaperColor, kPaperColor.withOpacity(0)],
                ),
              ),
              child: Center(
                child: Text(
                  "${DateFormat('yyyy.MM.dd').format(widget.chapter.startDate)}  ·  ${_contentController.text.length} 字",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 阅读视图构建器
  Widget _buildReader() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80), // 增加上下留白
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 标题区
          Center(
            child: Column(
              children: [
              Text(
                  _titleController.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold, 
                    color: kInkColor,
                    fontFamily: 'Serif', // 尝试调用系统衬线体
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 40, 
                  height: 2, 
                  color: kAccentColor.withOpacity(0.3),
              ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          // 正文区
            Text(
            _contentController.text,
            style: const TextStyle(
              fontSize: 17, // 稍大字号
              height: 1.85, // 宽松行高
              color: Color(0xFF333333),
              fontFamily: 'Serif', // 尝试调用系统衬线体
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 100), // 底部留白
          Center(child: Icon(Icons.eco_outlined, size: 16, color: Colors.grey[300])), // 文末装饰
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // 编辑视图构建器
  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Serif'),
            decoration: const InputDecoration(border: InputBorder.none, hintText: "章节标题"),
            ),
          const SizedBox(height: 20),
              TextField(
                controller: _contentController,
                maxLines: null,
            style: const TextStyle(fontSize: 16, height: 1.8),
                decoration: const InputDecoration(border: InputBorder.none, hintText: "正文内容..."),
              ),
          const SizedBox(height: 300), // 键盘避让区
          ],
      ),
    );
  }
}

