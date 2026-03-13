import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../time_service.dart';
import '../user_profile.dart';
import '../services/vector_store_service.dart';
import '../widgets/reasoning_display.dart'; // ✨ 引入推理显示组件

const Color kPageBackground = Color(0xFFF2F5F8);

class GlobalChatPage extends StatefulWidget {
  const GlobalChatPage({super.key});

  @override
  State<GlobalChatPage> createState() => _GlobalChatPageState();
}

class _GlobalChatPageState extends State<GlobalChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _quickActions = [
    "📅 总结一下我最近的状态",
    "🔮 根据我的性格，给我一点建议",
    "📉 我觉得最近有点内耗",
    "📖 推荐几本适合我现在读的书",
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory(); // ✅ 初始化时加载历史记录
  }

  // 📂 1. 加载历史记录
  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('global_chat_history');

    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        setState(() {
          _messages = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
        // 延迟滚动到底部
        Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
      } catch (e) {
        _initDefaultMessage();
      }
    } else {
      _initDefaultMessage();
    }
  }

  // 💾 2. 保存历史记录
  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_chat_history', jsonEncode(_messages));
  }

  // 🗑️ 3. 清空历史记录
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('global_chat_history');
    _initDefaultMessage();
  }

  void _initDefaultMessage() {
    setState(() {
      _messages = [
        {
          "role": "assistant",
          "content": "嗨！我是最懂你的 AI 伴侣。不管是当下的困惑，还是未来的规划，随时都可以跟我聊聊。"
        }
      ];
    });
  }

  Future<String> _buildSuperContext({String ragContext = ""}) async {
    final prefs = await SharedPreferences.getInstance();

    // 🌟 获取 AI 设置
    final String nickname = prefs.getString('ai_user_nickname') ?? "";
    final String styleName = prefs.getString('ai_style') ?? "温柔治愈型";
    final String customStylePrompt = prefs.getString('ai_custom_style_prompt') ?? "";
    String stylePrompt = "";
    
    if (styleName == "自定义风格" && customStylePrompt.isNotEmpty) {
      stylePrompt = "请用以下自定义风格回复：$customStylePrompt";
    } else {
      switch (styleName) {
        case "理性分析型":
          stylePrompt = "请用【理性分析型】风格回复。逻辑缜密，拆解问题，多用'第一、第二、第三'的结构，提供客观、可执行的建议。少用情绪化词汇，多用逻辑推导。";
          break;
        case "苏格拉底型":
          stylePrompt = "请用【苏格拉底型】风格回复。不要直接给出答案。多通过反问、隐喻来引导用户自己思考。像一位深邃的哲学家，激发用户的内省。";
          break;
        case "毒舌鞭策型":
          stylePrompt = "请用【毒舌鞭策型】风格回复。一针见血，不留情面地指出用户的思维误区和软弱之处。言辞犀利，旨在打破用户的自我欺骗和舒适区，助其成长。不要无脑安慰。";
          break;
        default: // 温柔治愈型
          stylePrompt = "请用【温柔治愈型】风格回复。语气要像一位知心姐姐，温暖、包容、充满鼓励。永远站在用户这一边，先共情，再安抚。";
      }
    }

    String callUser = nickname.isNotEmpty ? "请称呼用户为“$nickname”。" : "";
    
    // 获取画像
    String profileStr = "暂无画像";
    final String? profileJson = prefs.getString('user_persona');
    if (profileJson != null) {
      try {
        final profile = UserProfile.fromJson(jsonDecode(profileJson));
        profileStr = """
- 性格底色：${profile.personalityTraits.summary}
- 近期状态：${profile.recentState.summary}
- 核心价值观：${profile.coreValues.map((e) => e.value).join(', ')}
- 沟通偏好：${profile.communicationPreference.summary}
""";
      } catch (e) {
        profileStr = "画像解析失败";
      }
    }

    // 获取人生阶段
    String stageStr = "未知阶段";
    final String? currentStage = await TimeService.findLifeStageNameForDate(DateTime.now());
    if (currentStage != null) {
      stageStr = currentStage;
    }

    // 获取最近日记
    String recentDiaries = "";
    final String? diaryJson = prefs.getString('diary_data');
    if (diaryJson != null) {
      List<dynamic> list = jsonDecode(diaryJson);
      list.sort((a, b) => b['date'].compareTo(a['date'])); 
      recentDiaries = list.take(5).map((e) => "【${e['date']}】${e['content']}").join("\n");
    }

    String memoryBlock = "";
    if (ragContext.isNotEmpty) {
      memoryBlock += "\n【相关历史记忆 (Long-term Memory)】\n$ragContext\n";
    }
    if (recentDiaries.isNotEmpty) {
      memoryBlock += "\n【用户最近几天的日记 (Short-term Memory)】\n$recentDiaries";
    }

    return """
你是一个全知全能、深度共情的 AI 伴侣。你非常了解用户。
$callUser
$stylePrompt

【用户的核心档案】
$profileStr

【用户当前所处的人生阶段】
$stageStr
$memoryBlock

**交互准则：**
1. 你不是一个外人，你是用户内心世界的映射。请用温暖、理解、且一针见血的语调对话。
2. 结合“画像”和“记忆”来回答。例如，如果用户问“我该怎么办”，你要结合他的性格（内向/外向）和他最近遇到的具体困难来给出建议。
3. 如果用户提到过去的事情，请尝试联系他的人生阶段。
""";
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    HttpOverrides.global = _MyHttpOverrides();

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    _saveChatHistory(); // ✅ 发送即保存

    // 📌 使用用户配置的 API 设置（与日记内部聊天一致）
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('custom_api_key') ?? dotenv.env['API_KEY'] ?? ''; 
    final apiUrl = prefs.getString('custom_api_url') ?? dotenv.env['API_URL'] ?? 'https://api.deepseek.com/chat/completions';
    final modelName = prefs.getString('custom_model_name') ?? 
                     (apiUrl.contains("siliconflow") ? "deepseek-ai/DeepSeek-V3" : "deepseek-chat");

    try {
      // 🧠 RAG 检索：寻找相关记忆
      String ragContext = "";
      try {
        // 降低阈值到 0.45，扩大召回到 10 条，确保聊天记录中的补充信息能被检索到
        final results = await VectorStoreService.search(text, topK: 10);
        if (results.isNotEmpty) {
           final prefs = await SharedPreferences.getInstance();
           final String? diaryJson = prefs.getString('diary_data');
           if (diaryJson != null) {
             List<dynamic> allDiaries = jsonDecode(diaryJson);
             StringBuffer sb = StringBuffer();
             for (var res in results) {
               // 找到对应日期的日记
               var match = allDiaries.firstWhere((d) => d['date'] == res.key, orElse: () => null);
               if (match != null) {
                 String content = match['content'];
                 // 截断过长内容，但保留更多上下文 (500字)
                 if (content.length > 500) content = "${content.substring(0, 500)}...";
                 sb.writeln(">> 日记【${res.key}】:");
                 sb.writeln(content);

                 // ✨✨✨ 关键修复：把聊天记录中的补充信息也喂给 AI ✨✨✨
                 if (match['chat_history'] != null) {
                    try {
                      List<dynamic> history = jsonDecode(match['chat_history']);
                      StringBuffer chatBuf = StringBuffer();
                      // 只提取用户的发言，因为那是"补充信息"
                      // 也可以提取 AI 的，但为了节省 token，重点关注用户说的事实
                      for (var msg in history) {
                         if (msg['role'] == 'user') {
                           chatBuf.writeln("- ${msg['content']}");
                         }
                      }
                      if (chatBuf.isNotEmpty) {
                        sb.writeln("【该日记的背景补充 (用户在聊天中透露的)】:");
                        sb.writeln(chatBuf.toString());
                      }
                    } catch (e) {
                      // ignore
                    }
                 }
                 sb.writeln("(相关度: ${(res.value * 100).toStringAsFixed(0)}%)\n");
               }
             }
             ragContext = sb.toString();
             print("🔍 [RAG Context Final]:\n$ragContext"); // Debug print
           }
        }
      } catch (e) {
        debugPrint("RAG Search failed: $e");
      }

      final String systemPrompt = await _buildSuperContext(ragContext: ragContext);

      List<Map<String, String>> apiMessages = [
        {"role": "system", "content": systemPrompt}
      ];
      
      // 限制上下文长度，只带最近的 20 条，防止 Token 爆炸
      int startIndex = _messages.length > 20 ? _messages.length - 20 : 0;
      for (int i = startIndex; i < _messages.length; i++) {
        apiMessages.add({
          "role": _messages[i]['role'].toString(), 
          "content": _messages[i]['content'].toString()
        });
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": modelName,
          "messages": apiMessages,
          "temperature": 0.8,
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['choices']?[0]?['message'];
        
        if (message != null) {
          // ✨ 处理推理模型的推理内容
          String? reasoningContent = message['reasoning_content'];
          final String? content = message['content'];
          
          String aiReply = content ?? '';
          
          // 如果有推理内容，将其包装在 <think>标签中
          if (reasoningContent != null && reasoningContent.isNotEmpty) {
            aiReply = '<think>\n$reasoningContent\n</think>\n$aiReply';
            print('🧠 [推理内容已添加]: ${reasoningContent.length} 字符');
          }
          
          if (aiReply.isNotEmpty) {
            setState(() {
              _messages.add({"role": "assistant", "content": aiReply});
            });
            _saveChatHistory(); // ✅ AI 回复后保存
          }
        }
      } else {
        setState(() {
          _messages.add({"role": "assistant", "content": "（连接中断，状态码：${response.statusCode}）"});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "（网络错误: $e）"});
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor; // ✨ 获取动态主题色

    return Scaffold(
      backgroundColor: kPageBackground,
      appBar: AppBar(
        title: const Text("清言客", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          // ✨ 新增：清空聊天记录的垃圾桶按钮
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            tooltip: "清空记忆",
            onPressed: () {
              showDialog(
                context: context, 
                builder: (ctx) => AlertDialog(
                  title: const Text("重置对话"),
                  content: const Text("确定要清空与 清言客的聊天记录吗？\n（这不会影响日记和画像）"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
                    TextButton(
                      onPressed: () {
                        _clearHistory();
                        Navigator.pop(ctx);
                      }, 
                      child: const Text("清空", style: TextStyle(color: Colors.red))
                    ),
                  ],
                )
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? primaryColor : Colors.white, // ✨ 动态用户气泡色
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✨ 渲染思考内容（如果有）- 使用统一的可折叠组件
                        if (!isUser)
                          Builder(
                            builder: (context) {
                              final parsed = ReasoningResult.parse(msg['content'].toString());
                              if (parsed.hasReasoning) {
                                return ReasoningDisplay(reasoningText: parsed.reasoning!);
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        // ✨ 渲染正常回复
                        MarkdownBody(
                          data: () {
                            final parsed = ReasoningResult.parse(msg['content'].toString());
                            return parsed.finalResponse.isEmpty ? msg['content'].toString() : parsed.finalResponse;
                          }(),
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isUser ? Colors.white : const Color(0xFF333333),
                              fontSize: 15, height: 1.5,
                            ),
                            strong: TextStyle(
                              color: isUser ? Colors.white : primaryColor, // ✨ 动态强调色
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("AI 正在思考...", style: TextStyle(color: primaryColor.withOpacity(0.8))), // ✨ 动态提示色
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            color: kPageBackground,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickActions.map((action) => Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: ActionChip(
                        label: Text(action, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _sendMessage(action),
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: primaryColor.withOpacity(0.3)), // ✨ 动态边框色
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF555555)),
                      ),
                    )).toList(),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: "和 AI 聊聊...",
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _sendMessage(_controller.text),
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle), // ✨ 动态发送按钮色
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}