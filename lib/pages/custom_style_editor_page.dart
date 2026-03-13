import 'package:flutter/material.dart';

class CustomStyleEditorPage extends StatefulWidget {
  final String initialPrompt;
  final Color primaryColor;

  const CustomStyleEditorPage({
    super.key,
    required this.initialPrompt,
    required this.primaryColor,
  });

  @override
  State<CustomStyleEditorPage> createState() => _CustomStyleEditorPageState();
}

class _CustomStyleEditorPageState extends State<CustomStyleEditorPage> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("自定义 AI 风格", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _controller.text.trim());
            },
            child: Text("完成", style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "定义你的专属 AI 伴侣风格",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "请输入你希望 AI 如何回复的详细描述，比如语气、表达方式、沟通风格等。",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: "例如：请用幽默风趣的语气回复，多使用比喻和类比，避免过于严肃，偶尔可以开个小玩笑...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "💡 提示：",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "• 描述语气风格：如温和、幽默、专业、犀利等\n"
                      "• 说明表达方式：如多用比喻、逻辑分析、反问引导等\n"
                      "• 设定互动模式：如鼓励为主、挑战思维、简洁明了等\n"
                      "• 可参考现有风格描述进行调整",
                      style: TextStyle(fontSize: 13, color: Colors.blue[700], height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}