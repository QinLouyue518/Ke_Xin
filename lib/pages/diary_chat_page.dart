import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../time_service.dart'; // 引入 TimeService
import '../services/vector_store_service.dart'; // ✨ 引入向量服务
import '../services/api_settings_service.dart'; // ✨ 引入 API 配置服务
import '../widgets/reasoning_display.dart'; // ✨ 引入推理显示组件

// 定义我们的莫兰迪主色 (已废弃，改用 Theme)
// const Color kMorandiBlue = Color(0xFF7CA1B4);
const Color kAIBackground = Colors.white;
const Color kPageBackground = Color(0xFFF2F5F8); // 极淡的蓝灰背景

class DiaryChatPage extends StatefulWidget {
  final Map<String, String> entry;
  final Function(Map<String, String>) onUpdate;

  const DiaryChatPage({super.key, required this.entry, required this.onUpdate});

  @override
  State<DiaryChatPage> createState() => _DiaryChatPageState();
}

class _DiaryChatPageState extends State<DiaryChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _quickActions = [
    "🤔 深度分析我的情绪",
    "💡 下次遇到这种事该怎么办？",
    "🧠 从心理学角度分析我的潜意识",
    "🧘 给我一些安慰和鼓励",
    "⚖️ 客观评价一下这件事",
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    // 🧠 在页面销毁时，如果产生了新的聊天内容，自动更新到向量库
    _updateVectorIndex();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✨ 将用户的聊天补充内容合并到向量库
  Future<void> _updateVectorIndex() async {
    if (_messages.isEmpty) return;

    // 1. 提取用户发言
    StringBuffer userSupplements = StringBuffer();
    for (var msg in _messages) {
      if (msg['role'] == 'user') {
        userSupplements.writeln(msg['content']);
      }
    }

    if (userSupplements.isEmpty) return;

    // 2. 拼接：日记原文 + 用户补充
    String fullContent = "${widget.entry['content']}\n\n【事后补充的背景信息】\n${userSupplements.toString()}";

    // 3. 更新索引 (覆盖旧的)
    // 注意：这里我们用日记的 date 作为 key。
    // VectorStoreService.indexDiary 会自动覆盖同一个 key 的数据。
    if (widget.entry['date'] != null) {
      debugPrint("正在更新日记 [${widget.entry['date']}] 的向量索引 (含聊天补充)...");
      await VectorStoreService.indexDiary(widget.entry['date']!, fullContent);
    }
  }

  void _loadChatHistory() {
    if (widget.entry.containsKey('chat_history') && widget.entry['chat_history']!.isNotEmpty) {
      try {
        final List<dynamic> historyJson = jsonDecode(widget.entry['chat_history']!);
        setState(() {
          _messages = historyJson.map((e) => Map<String, dynamic>.from(e)).toList();
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      } catch (e) {
        _initDefaultMessage();
      }
    } else {
      _initDefaultMessage();
    }
  }

  void _initDefaultMessage() {
    String initialContent = "我在听。关于这篇日记，你想聊点什么？";
    if (widget.entry.containsKey('question') && widget.entry['question'] != null && widget.entry['question']!.isNotEmpty) {
      initialContent = "我在听。读完这篇日记，我想问你：\n\n**${widget.entry['question']}**\n\n你怎么看？";
    }

    setState(() {
      _messages = [
        {
          "role": "assistant",
          "content": initialContent
        }
      ];
    });
  }

  void _saveChatHistory() {
    String historyString = jsonEncode(_messages);
    Map<String, String> updatedEntry = Map<String, String>.from(widget.entry);
    updatedEntry['chat_history'] = historyString;
    widget.onUpdate(updatedEntry);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final String userPersona = prefs.getString('user_persona') ?? "用户是一个普通的大学生。";
    
    // 🌟 获取 AI 设置
    final String nickname = prefs.getString('ai_user_nickname') ?? "";
    final String styleName = prefs.getString('ai_style') ?? "温柔治愈型";
    String stylePrompt = "";

    switch (styleName) {
      case "理性分析型":
        stylePrompt = "请用【理性分析型】风格回复。逻辑缜密，拆解问题，多用“第一、第二、第三”的结构，提供客观、可执行的建议。少用情绪化词汇。";
        break;
      case "苏格拉底型":
        stylePrompt = "请用【苏格拉底型】风格回复。不要直接给出答案。多通过反问、隐喻来引导用户自己思考。";
        break;
      case "毒舌鞭策型":
        stylePrompt = "请用【毒舌鞭策型】风格回复。一针见血，不留情面地指出用户的思维误区。";
        break;
      default: // 温柔治愈型
        stylePrompt = "请用【温柔治愈型】风格回复。温暖、包容、充满鼓励。";
    }

    String callUser = nickname.isNotEmpty ? "请称呼用户为“$nickname”。" : "";

    // 获取当前日记的日期
    final DateTime diaryDate = DateTime.parse(widget.entry['date']!);
    // 获取当前日记所属的人生阶段
    final String? lifeStageName = await TimeService.findLifeStageNameForDate(diaryDate);

    // 忽略 SSL
    HttpOverrides.global = _MyHttpOverrides();

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    _saveChatHistory();

    // 从自定义配置读取 API 信息
    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();

    // 如果未配置 API Key，提示用户
    if (apiKey.isEmpty) {
      _showConfigRequiredDialog();
      setState(() => _isTyping = false);
      return;
    }

    try {
      List<Map<String, String>> apiMessages = [
        {
          "role": "system",
          "content": """
你是一个专业、温柔的心理咨询师。
$callUser
$stylePrompt

**你非常了解用户，以下是用户的【个人画像】，请务必基于此画像的语境来回答：**
【$userPersona】

【重要背景知识】 - 你正在讨论的这篇日记，写于【${diaryDate.year}年${diaryDate.month}月${diaryDate.day}日】，当时用户正处于【${lifeStageName ?? '人生阶段未知'}】。
日记内容是：【${widget.entry['content']}】

请遵循以下原则：
1. **基于画像**：结合用户的性格和过往经历来给出建议。
2. **深度共情**：尝试解读潜意识。
3. **详细展开**：回答要有逻辑、分层次，使用 Markdown 格式。
4. **风格一致**：严格遵守设定的【$styleName】。
"""
        }
      ];
      
      for (var msg in _messages) {
        apiMessages.add({
          "role": msg['role'].toString(), 
          "content": msg['content'].toString()
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
          "temperature": 0.7,
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(seconds: 200));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['choices']?[0]?['message'];
        
        if (message != null) {
          // ✨ 处理 reasoner 模型的推理内容
          String? reasoningContent = message['reasoning_content'];
          final String? content = message['content'];
          
          String aiReply = content ?? '';
          
          // 如果有推理内容，将其包装在 <think> 标签中
          if (reasoningContent != null && reasoningContent.isNotEmpty) {
            aiReply = '<think>\n$reasoningContent\n</think>\n$aiReply';
          }
          
          if (aiReply.isNotEmpty) {
            setState(() {
              _messages.add({"role": "assistant", "content": aiReply});
            });
            _saveChatHistory();
          }
        }
      } else {
        setState(() {
          _messages.add({"role": "assistant", "content": "（服务器开小差了，状态码：${response.statusCode}）"});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "（连接超时或中断: $e）"});
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
    final primaryColor = Theme.of(context).primaryColor; // ✨ 获取动态主题色

    return Scaffold(
      backgroundColor: kPageBackground, // ✨ 页面背景色
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 透明导航栏
        title: Hero(
          tag: 'diary_tag_${widget.entry['date']}_${widget.entry['content']}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              widget.entry['mood_keyword'] ?? '日记详情',
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w600, 
                color: Color(0xFF333333)
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 2. 聊天记录列表
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
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      // ✨ 动态使用主题色
                      color: isUser ? primaryColor : kAIBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4), // 气泡尾巴
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                      // 给 AI 的白色气泡加一个极细的边框，防止和背景融为一体
                      border: isUser ? null : Border.all(color: Colors.black.withOpacity(0.03)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 推理显示组件（仅在 AI 消息且包含推理标签时显示）
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
                        // 最终回复内容
                        MarkdownBody(
                          data: () {
                            final parsed = ReasoningResult.parse(msg['content'].toString());
                            return parsed.finalResponse.isEmpty ? msg['content'].toString() : parsed.finalResponse;
                          }(),
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isUser ? Colors.white : const Color(0xFF333333),
                              fontSize: 15,
                              height: 1.5,
                            ),
                            strong: TextStyle(
                              color: isUser ? Colors.white : primaryColor, // ✨ 动态高亮色
                              fontWeight: FontWeight.bold
                            ),
                            h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            listBullet: TextStyle(color: isUser ? Colors.white : primaryColor), // ✨ 动态列表点色
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. 正在输入提示
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 12, height: 12, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor.withOpacity(0.6)) // ✨ 动态色
                  ),
                  const SizedBox(width: 8),
                  Text("AI 正在思考...", style: TextStyle(fontSize: 12, color: primaryColor.withOpacity(0.8))), // ✨ 动态色
                ],
              ),
            ),

          // 4. 底部输入区 (悬浮胶囊风格)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: const BoxDecoration(
              color: kPageBackground, // 与背景同色，制造悬浮感
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 快捷指令
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickActions.map((action) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                        child: ActionChip(
                          label: Text(action, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: primaryColor.withOpacity(0.3)), // ✨ 动态边框色
                          ),
                          labelStyle: const TextStyle(color: Color(0xFF555555)),
                          onPressed: () => _sendMessage(action),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // 输入框
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
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
                    // 发送按钮
                    GestureDetector(
                      onTap: () => _sendMessage(_controller.text),
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: primaryColor, // ✨ 动态发送按钮色
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)) // ✨ 动态阴影色
                          ],
                        ),
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