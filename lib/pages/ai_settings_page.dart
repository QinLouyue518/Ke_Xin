import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_style_editor_page.dart';

class AISettingsPage extends StatefulWidget {
  const AISettingsPage({super.key});

  @override
  State<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends State<AISettingsPage> {
  final TextEditingController _nicknameController = TextEditingController();
  String _selectedStyle = "温柔治愈型"; // 默认风格
  String _customStylePrompt = ""; // 自定义风格 prompt

  final Map<String, String> _styleDescriptions = {
    "温柔治愈型": "以鼓励、安抚为主，像一位知心姐姐，永远站在你这边。",
    "理性分析型": "逻辑缜密，帮你拆解问题，提供客观建议，像一位睿智的导师。",
    "苏格拉底型": "多提问少回答，引导你自己寻找答案，像一位深刻的哲学家。",
    "毒舌鞭策型": "一针见血，不留情面地指出你的问题，助你打破舒适区。",
    "自定义风格": "完全由你定义的专属 AI 伴侣风格。",
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nicknameController.text = prefs.getString('ai_user_nickname') ?? "";
      _selectedStyle = prefs.getString('ai_style') ?? "温柔治愈型";
      _customStylePrompt = prefs.getString('ai_custom_style_prompt') ?? "";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_user_nickname', _nicknameController.text.trim());
    await prefs.setString('ai_style', _selectedStyle);
    await prefs.setString('ai_custom_style_prompt', _customStylePrompt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI 设置已更新")));
      Navigator.pop(context);
    }
  }

  void _navigateToCustomStyleEditor(BuildContext context) async {
    final primaryColor = Theme.of(context).primaryColor;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomStyleEditorPage(
          initialPrompt: _customStylePrompt,
          primaryColor: primaryColor,
        ),
      ),
    );
    
    if (result != null && result is String) {
      setState(() {
        _customStylePrompt = result;
        _selectedStyle = "自定义风格";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI 伴侣设置", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. 称呼设置
          const Text("AI 对我的称呼", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              hintText: "例如：主人、阿强、小主...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          const Text("如果不填，AI 会根据语境自然称呼你。", style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          const SizedBox(height: 32),

          // 2. 性格设置
          const Text("AI 回复风格", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._styleDescriptions.keys.map((style) {
            final isSelected = _selectedStyle == style;
            final isCustomStyle = style == "自定义风格";
            return GestureDetector(
              onTap: () {
                if (isCustomStyle) {
                  _navigateToCustomStyleEditor(context);
                } else {
                  setState(() {
                    _selectedStyle = style;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(style, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? primaryColor : Colors.black87)),
                              if (isCustomStyle) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.edit, size: 14, color: primaryColor.withOpacity(0.7)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(_styleDescriptions[style]!, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: primaryColor)
                    else
                      const Icon(Icons.circle_outlined, color: Colors.grey),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 40),
          
          // 保存按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 2,
              ),
              child: const Text("保存设置", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

