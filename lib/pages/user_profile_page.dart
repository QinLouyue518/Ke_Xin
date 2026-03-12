import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../user_profile.dart'; // 引入 UserProfile 数据模型
import '../life_stage.dart'; // 引入 LifeStage 数据模型
import '../time_service.dart'; // 引入 TimeService
import 'life_stages_page.dart'; // 引入 LifeStagesPage
import 'package:intl/intl.dart'; // 引入 DateFormat
import '../services/api_settings_service.dart'; // ✨ 引入 API 配置服务

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserProfile _userProfile = UserProfile.empty();
  bool _isAnalyzing = false;

  // 基础信息 Map
  Map<String, String> _basicInfo = {
    "昵称": "",
    "年龄": "",
    "身份": "",
    "学校/机构": "",
    "性格关键词": "",
  };

  // 固定的 5 个核心字段 Key (用于排序和固定显示)
  final List<String> _fixedKeys = ["昵称", "年龄", "身份", "学校/机构", "性格关键词"];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 加载画像
      String? personaJson = prefs.getString('user_persona');
      if (personaJson != null && personaJson.isNotEmpty) {
        try {
          _userProfile = UserProfile.fromJson(jsonDecode(personaJson));
        } catch (e) {
          _userProfile = UserProfile.empty();
        }
      }

      // 加载基础信息
      String? infoString = prefs.getString('user_basic_info');
      if (infoString != null) {
        Map<String, dynamic> decoded = jsonDecode(infoString);
        // 转换并合并，确保固定字段存在
        Map<String, String> loaded = Map<String, String>.from(decoded);
        _basicInfo.addAll(loaded);
      }
    });
  }

  // ✨ 升级版编辑弹窗：支持动态添加字段
  void _editBasicInfo() {
    // 1. 准备控制器：分为固定组和自定义组
    Map<String, TextEditingController> fixedControllers = {};
    for (var key in _fixedKeys) {
      fixedControllers[key] = TextEditingController(text: _basicInfo[key] ?? "");
    }

    // 找出所有非固定的自定义字段
    List<MapEntry<TextEditingController, TextEditingController>> customControllers = [];
    _basicInfo.forEach((key, value) {
      if (!_fixedKeys.contains(key)) {
        customControllers.add(MapEntry(
          TextEditingController(text: key),
          TextEditingController(text: value),
        ));
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // 使用 StatefulBuilder 让弹窗内部可刷新
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("编辑基础档案"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 固定字段区域 ---
                    ..._fixedKeys.map((key) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: fixedControllers[key],
                        decoration: InputDecoration(
                          labelText: key,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    )),
                    
                    const Divider(height: 30),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("更多信息 (最多30条)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),

                    // --- 自定义字段区域 ---
                    ...customControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      var controllers = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: controllers.key,
                                decoration: const InputDecoration(
                                  hintText: "标题(如:家乡)",
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 5,
                              child: TextField(
                                controller: controllers.value,
                                decoration: const InputDecoration(
                                  hintText: "内容",
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                setStateDialog(() {
                                  customControllers.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                    // --- 添加按钮 ---
                    if (customControllers.length + _fixedKeys.length < 30) // 限制总数
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("添加自定义项"),
                        onPressed: () {
                          setStateDialog(() {
                            customControllers.add(MapEntry(
                              TextEditingController(),
                              TextEditingController(),
                            ));
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
              ElevatedButton(
                onPressed: () async {
                  // 收集数据
                  Map<String, String> newInfo = {};
                  
                  // 1. 收集固定字段
                  fixedControllers.forEach((key, ctrl) {
                    newInfo[key] = ctrl.text.trim();
                  });

                  // 2. 收集自定义字段
                  for (var entry in customControllers) {
                    String key = entry.key.text.trim();
                    String value = entry.value.text.trim();
                    if (key.isNotEmpty && value.isNotEmpty) {
                      newInfo[key] = value;
                    }
                  }

                  setState(() {
                    _basicInfo = newInfo;
                  });
                  
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_basic_info', jsonEncode(_basicInfo));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("保存"),
              ),
            ],
          );
        }
      ),
    );
  }


  // ✨ 新增：按时间距离加权采样日记
  String _getWeightedDiarySelection(List<dynamic> allDiaries) {
    if (allDiaries.isEmpty) return "";
    
    // 假设 allDiaries 已经是按时间倒序排列 (最新的在前面)
    List<dynamic> selected = [];
    
    for (int i = 0; i < allDiaries.length; i++) {
      if (i < 10) {
        // 第一梯队（近期）：前 10 篇，100% 采样
        selected.add(allDiaries[i]);
      } else if (i < 40) {
        // 第二梯队（中期）：11-40 篇，每 3 篇取 1 篇
        if ((i - 10) % 3 == 0) {
          selected.add(allDiaries[i]);
        }
      } else {
        // 第三梯队（远期）：40 篇以后，每 10 篇取 1 篇
        if ((i - 40) % 10 == 0) {
          selected.add(allDiaries[i]);
        }
      }
      
      // 硬性上限保护，防止 Token 溢出
      if (selected.length >= 35) break; 
    }
    
    return selected.map((e) {
      // 简单的截断保护，防止单篇过长
      String content = e['content'] ?? "";
      if (content.length > 500) {
        content = "${content.substring(0, 500)}...(已截断)";
      }
      return "[ID: diary_${allDiaries.indexOf(e)}] 【${e['date']}】$content";
    }).join("\n");
  }

  // AI 逻辑升级：遍历整个 Map 构建 Prompt
  Future<void> _generatePersona() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. 获取日记
      String diaryContext = "";
      final String? jsonString = prefs.getString('diary_data');
      if (jsonString != null) {
        List<dynamic> list = jsonDecode(jsonString);
        
        // ✨ 安全加固：确保日记按日期降序排列 (最新的在前)，保证采样逻辑准确
        list.sort((a, b) {
          String dateA = a['date'] ?? '';
          String dateB = b['date'] ?? '';
          return dateB.compareTo(dateA);
        });

        // ✨ 使用加权采样逻辑
        diaryContext = _getWeightedDiarySelection(list);
      }

      // 2. 获取基础信息 (升级版：遍历所有 KV)
      StringBuffer basicInfoBuffer = StringBuffer();
      basicInfoBuffer.writeln("【用户基础档案】");
      _basicInfo.forEach((key, value) {
        if (value.isNotEmpty) {
          basicInfoBuffer.writeln("- $key: $value");
        }
      });
      String basicInfoContext = basicInfoBuffer.toString();

      // 2.5 获取人生阶段信息
      final List<LifeStage> lifeStages = await TimeService.loadLifeStages();
      String lifeStageContext = "";
      if (lifeStages.isNotEmpty) {
        lifeStageContext = "【人生阶段】:\n" + lifeStages.map((s) => "- ${s.name} (${s.startDate.year}-${s.endDate.year}) - 标签: ${s.tags.join(', ')}").join("\n");
      }

      String fullUserContent = basicInfoContext;
      if (lifeStageContext.isNotEmpty) {
        fullUserContent += "\n\n" + lifeStageContext;
      }
      if (diaryContext.isNotEmpty) {
        fullUserContent += "\n\n【最近的日记内容】：\n" + diaryContext;
      }

      if (diaryContext.isEmpty && basicInfoContext.length < 20) {
        // ... 错误处理
        setState(() { _isAnalyzing = false; });
        return;
      }

      // 3. 准备调用 AI
      final apiKey = await ApiSettingsService.getApiKey();
      final apiUrl = await ApiSettingsService.getApiUrl();
      final modelName = await ApiSettingsService.getModelName();

      // 如果未配置 API Key，提示用户
      if (apiKey.isEmpty) {
        _showConfigRequiredDialog();
        setState(() { _isAnalyzing = false; });
        return;
      }

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
你是一个专业的侧写师。请结合用户的【基础档案】、**【人生阶段数据】**和【过往日记】，生成一份深度个人画像。请严格按照以下 JSON 格式返回数据，不要包含 Markdown 标记或其他废话：
{
  "personality_traits": {
    "summary": "对用户的整体性格总结 (第二人称)",
    "tags": ["INFP", "高敏感"],
    "evidence_ids": ["[ID: diary_0]", "[ID: diary_1]"]
  },
  "core_values": [
    {"value": "核心价值观1", "description": "一段话解释为什么得出这个结论，并直接引用日记中的关键字句作为证据 (引用时请注明[来自日记ID])", "evidence_ids": ["[ID: diary_2]"]}
  ],
  "thinking_patterns": [
    {"pattern": "思维模式1", "description": "一段话解释为什么得出这个结论，并直接引用日记中的关键字句作为证据 (引用时请注明[来自日记ID])", "evidence_ids": ["[ID: diary_3]"]}
  ],
  "recent_state": {
    "summary": "对用户近期状态的总结",
    "keywords": ["学业压力", "焦虑"],
    "evidence_ids": ["[ID: diary_4]"]
  },
  "communication_preference": {
    "summary": "对用户沟通偏好的总结",
    "style": "鼓励式",
    "evidence_ids": ["[ID: diary_5]"]
  }
}

如果某个字段没有内容，请返回其对应的空值（例如，summary 为空字符串 ""，tags 或 evidence_ids 为空列表 []）。请务必返回完整的 JSON 结构，不要遗漏任何字段。

注意：
1. **基础档案**是事实依据，请直接采纳。
2. **过往日记**用于分析用户的心理状态、价值观和潜在性格。请使用方括号中的 "ID: diary_索引" 作为 `evidence_ids`。
3. **人生阶段数据**：用于理解用户当前所处的人生阶段背景，参考每个阶段的名称、起止年份和标签。**请将人生阶段数据与日记内容进行关联，以便更全面地分析用户的心理状态。**
4. 请用**第二人称**（你...）直接描述 `personality_traits.summary`, `recent_state.summary`, `communication_preference.summary`。
5. `core_values` 和 `thinking_patterns` 中的 `description` 字段需要详细解释结论，并直接引用日记原文的关键字句作为证据，引用格式为 `(引用时请注明[来自日记ID])`。
6. 归纳维度：人格特质、核心价值观、思维模式、近期状态、沟通偏好。
"""
            },
            {
              "role": "user",
              "content": fullUserContent
            }
          ],
          "temperature": 0.5,
          "response_format": {"type": "json_object"},
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String? aiText = data['choices']?[0]?['message']?['content'];

        if (aiText != null) {
          try {
            final userProfile = UserProfile.fromJson(jsonDecode(aiText));
            await prefs.setString('user_persona', jsonEncode(userProfile.toJson()));
            setState(() {
              _userProfile = userProfile;
            });
          } catch (e) {
            debugPrint("JSON解析错误: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("网络错误: $e");
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // 弹窗展示证据
  void _showEvidenceDialog(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('diary_data');
    if (jsonString == null) return;

    List<dynamic> allDiaries = jsonDecode(jsonString);
    List<Map<String, dynamic>> evidences = [];

    // 简单匹配：这里假设 ID 格式是 diary_INDEX
    for (String id in ids) {
      try {
        int index = int.parse(id.replaceAll(RegExp(r'[^0-9]'), '')); // 提取数字
        if (index < allDiaries.length) {
          evidences.add(Map<String, dynamic>.from(allDiaries[index]));
        }
      } catch (e) {
        // ID 解析失败忽略
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("关联记忆片段"),
        content: SizedBox(
          width: double.maxFinite,
          child: evidences.isEmpty 
            ? const Text("未找到具体关联日记")
            : ListView.builder(
                shrinkWrap: true,
                itemCount: evidences.length,
                itemBuilder: (context, index) {
                  var d = evidences[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(d['date']?.toString() ?? '', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text(d['content']?.toString() ?? '', style: const TextStyle(fontSize: 14), maxLines: 4, overflow: TextOverflow.ellipsis),
                    ),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("关闭"))],
      ),
    );
  }

  // --- UI 构建方法 ---

  Widget _buildAnalysisListCard(String title, List<dynamic> items, Color color, IconData icon) {
    // ✨ 动态主题色
    final primaryColor = Theme.of(context).primaryColor;
    // 使用主题色替代传入的固定颜色，或者基于主题色计算
    // 这里为了保持语义（比如价值观、思维模式），我们可以保留原来的逻辑，或者统一用主题色。
    // 为了美观，建议统一用主题色，但用不同深浅来区分？
    // 既然用户选了主题，那就用主题色吧！
    final displayColor = primaryColor;

    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: displayColor), // ✨ 动态色
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: displayColor)), // ✨ 动态色
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            String label = item is CoreValue ? item.value : (item as ThinkingPattern).pattern;
            String desc = item is CoreValue ? item.description : (item as ThinkingPattern).description;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: displayColor.withOpacity(0.1), // ✨ 动态色
                          borderRadius: BorderRadius.circular(4), 
                          border: Border.all(color: displayColor.withOpacity(0.3)) // ✨ 动态色
                        ),
                        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: displayColor, fontSize: 13)), // ✨ 动态色
                      ),
                      const Spacer(),
                      // 移除原有的右上角搜索按钮
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // ✨ 新逻辑：使用 RichText 实现“文本内嵌可点击图标”的效果
                  Builder(
                    builder: (context) {
                      final List<InlineSpan> spans = [];
                      String text = desc;
                      
                      // 正则匹配：[来自日记ID: diary_xxx]
                      // 注意：AI 返回的格式可能是 [来自日记ID: diary_xxx] 或 [ID: diary_xxx]
                      // 我们之前 Prompt 让它用 (引用时请注明[来自日记ID])，所以可能会有 "来自日记ID: " 这样的前缀
                      // 为了兼容性，我们匹配方括号内的内容
                      final RegExp exp = RegExp(r'\[(.*?)\]'); 
                      
                      int lastMatchEnd = 0;
                      
                      for (final Match match in exp.allMatches(text)) {
                        // 添加普通文本
                        if (match.start > lastMatchEnd) {
                          spans.add(TextSpan(
                            text: text.substring(lastMatchEnd, match.start),
                            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                          ));
                        }
                        
                        String matchText = match.group(0)!; // 完整的 [xxx]
                        String innerContent = match.group(1)!; // xxx
                        
                        // 提取 ID (简单的提取逻辑：只要包含 diary_ 数字的就算)
                        // 这样即使 AI 写成 [来自日记ID: diary_1] 也能识别出 diary_1
                        if (innerContent.contains("diary_")) {
                          // 找到了 ID，渲染成 🔍 图标
                          
                          // 提取纯 ID 用于查找
                          // 这里我们不需要太精确提取 ID 字符串传给 _showEvidenceDialog，
                          // 因为 _showEvidenceDialog 内部已经有提取逻辑了，只要传进去含有 diary_xx 的字符串即可。
                          // 但是，为了精准弹窗，我们最好还是传 id 列表。
                          // 这里我们点击某一个图标，只显示那一个证据？还是显示所有？
                          // 用户期望的是点击图标查看对应的那篇日记。
                          
                          spans.add(WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: InkWell(
                                onTap: () => _showEvidenceDialog([innerContent]), // 传递当前这个 ID
                                child: Icon(Icons.search, size: 16, color: displayColor.withOpacity(0.6)), // ✨ 动态色
                              ),
                            ),
                          ));
                        } else {
                          // 如果不是日记引用（只是普通的方括号内容），照常显示
                          spans.add(TextSpan(
                            text: matchText,
                            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                          ));
                        }
                        
                        lastMatchEnd = match.end;
                      }
                      
                      // 添加剩余文本
                      if (lastMatchEnd < text.length) {
                        spans.add(TextSpan(
                          text: text.substring(lastMatchEnd),
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                        ));
                      }
                      
                      return RichText(text: TextSpan(children: spans));
                    }
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentStateCard() {
    final primaryColor = Theme.of(context).primaryColor; // ✨ 动态主题色

    if (_userProfile.recentState.summary.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.25)], // ✨ 动态渐变背景
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sentiment_satisfied_alt, color: primaryColor), // ✨ 动态色
              const SizedBox(width: 8),
              Text("近期状态", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)), // ✨ 动态色
              const Spacer(),
              if (_userProfile.recentState.evidenceIds.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.search, size: 20, color: primaryColor), // ✨ 动态色
                  onPressed: () => _showEvidenceDialog(_userProfile.recentState.evidenceIds),
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(_userProfile.recentState.summary, style: const TextStyle(height: 1.6, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _userProfile.recentState.keywords.map((k) => 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: primaryColor), borderRadius: BorderRadius.circular(8)), // ✨ 动态色
                child: Text(k, style: TextStyle(fontSize: 12, color: primaryColor)), // ✨ 动态色
              )
            ).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildPersonalityCard() {
    final primaryColor = Theme.of(context).primaryColor; // ✨ 动态主题色

    if (_userProfile.personalityTraits.summary.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: primaryColor), // ✨ 动态色
              const SizedBox(width: 8),
              Text("人格特质", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)), // ✨ 动态色
              const Spacer(),
              if (_userProfile.personalityTraits.evidenceIds.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.search, size: 20, color: primaryColor), // ✨ 动态色
                  onPressed: () => _showEvidenceDialog(_userProfile.personalityTraits.evidenceIds),
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(_userProfile.personalityTraits.summary, style: const TextStyle(height: 1.6, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _userProfile.personalityTraits.tags.map((t) => 
              Chip(
                label: Text(t, style: TextStyle(fontSize: 12, color: primaryColor)), // ✨ 动态色
                backgroundColor: primaryColor.withOpacity(0.1), // ✨ 动态色
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              )
            ).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    final primaryColor = Theme.of(context).primaryColor; // ✨ 动态主题色

    return InkWell(
      onTap: _editBasicInfo,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryColor.withOpacity(0.2)), // ✨ 动态色
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, color: primaryColor), // ✨ 动态色
                const SizedBox(width: 10),
                Text("基础档案 (点击编辑)", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16)), // ✨ 动态色
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _basicInfo.entries.where((e) => e.value.isNotEmpty).map((e) {
                // _buildTag 内部也需要修改，不过这里我们直接把颜色参数传进去即可
                // 原来的 Colors.blueGrey 改为 primaryColor
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1), // ✨ 动态色
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)), // ✨ 动态色
                  ),
                  child: Text("${e.key}: ${e.value}", style: TextStyle(fontSize: 12, color: primaryColor)), // ✨ 动态色
                );
              }).toList(),
            ),
            if (_basicInfo.values.every((v) => v.isEmpty))
              const Text("暂无信息，点击填写...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  // 新增：人生阶段管理入口卡片
  Widget _buildLifeStagesEntryCard() {
    final primaryColor = Theme.of(context).primaryColor; // ✨ 动态主题色

    return FutureBuilder<List<LifeStage>>(
      future: TimeService.loadLifeStages(),
      builder: (context, snapshot) {
        List<LifeStage> lifeStages = snapshot.data ?? [];
        return InkWell(
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LifeStagesPage()));
            // 从 LifeStagesPage 返回后刷新当前页面数据
            _loadAllData(); 
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withOpacity(0.2)), // ✨ 动态色
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timeline, color: primaryColor), // ✨ 动态色
                    const SizedBox(width: 10),
                    Text("人生阶段", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16)), // ✨ 修正文案
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting) 
                  const Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (lifeStages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: lifeStages.map((stage) => 
                      Chip(
                        label: Text("${stage.name} (${DateFormat('yyyy').format(stage.startDate)}-${DateFormat('yyyy').format(stage.endDate)})"),
                        backgroundColor: primaryColor.withOpacity(0.1), // ✨ 动态色
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        labelStyle: TextStyle(fontSize: 12, color: primaryColor), // ✨ 动态色
                      )
                    ).toList(),
                  )
                ] else 
                  const Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: Text("暂无记录，点击添加...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
        );
      },
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("素心鉴"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. 基础档案卡片 (可点击编辑)
            _buildBasicInfoCard(),
            
            const SizedBox(height: 24),

            // 人生阶段管理入口
            _buildLifeStagesEntryCard(),
            const SizedBox(height: 24),

            // 2. 五维画像展示
            if (_userProfile.personalityTraits.summary.isNotEmpty ||
                _userProfile.coreValues.isNotEmpty ||
                _userProfile.thinkingPatterns.isNotEmpty ||
                _userProfile.recentState.summary.isNotEmpty ||
                _userProfile.communicationPreference.summary.isNotEmpty) ...[
              _buildRecentStateCard(),
              const SizedBox(height: 16),
              _buildPersonalityCard(),
              const SizedBox(height: 16),
              _buildAnalysisListCard("核心价值观", _userProfile.coreValues, Colors.blue, Icons.diamond_outlined),
              const SizedBox(height: 16),
              _buildAnalysisListCard("思维模式", _userProfile.thinkingPatterns, Colors.teal, Icons.psychology_alt_outlined),
              const SizedBox(height: 16),
              // 沟通偏好
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.chat_bubble_outline, color: Colors.pink), SizedBox(width: 8), Text("沟通偏好", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink))]),
                  const SizedBox(height: 10),
                  Text("风格：${_userProfile.communicationPreference.style}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_userProfile.communicationPreference.summary, style: const TextStyle(height: 1.5))
                ]),
              ),
            ] else 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text("暂无画像，请点击下方按钮生成", style: TextStyle(color: Colors.grey)),
              ),

            const SizedBox(height: 80), // 底部留白
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 56,
        child: FloatingActionButton.extended(
          onPressed: _isAnalyzing ? null : _generatePersona,
          backgroundColor: Theme.of(context).primaryColor, // ✨ 统一为主题色
          foregroundColor: Colors.white,
          elevation: 4,
          icon: _isAnalyzing 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.auto_awesome),
          label: Text(_isAnalyzing ? "正在深度侧写..." : "更新你的画像", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}