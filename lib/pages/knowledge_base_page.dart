import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/vector_store_service.dart';

class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  bool _isIndexing = false;
  double _progress = 0.0;
  int _totalDiaries = 0;
  int _indexedCount = 0;
  String _statusMessage = "准备就绪";

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? diaryJson = prefs.getString('diary_data');
    if (diaryJson != null) {
      List<dynamic> list = jsonDecode(diaryJson);
      _totalDiaries = list.length;
    }
    
    // 向量存储服务会自动初始化
    _indexedCount = 0; // 暂时设置为0，实际需要实现统计逻辑
    
    if (mounted) setState(() {});
  }

  Future<void> _startIndexing() async {
    setState(() {
      _isIndexing = true;
      _progress = 0.0;
      _statusMessage = "正在读取日记...";
    });

    final prefs = await SharedPreferences.getInstance();
    final String? diaryJson = prefs.getString('diary_data');
    if (diaryJson == null) {
      setState(() {
        _isIndexing = false;
        _statusMessage = "没有日记可索引";
      });
      return;
    }

    List<dynamic> rawList = jsonDecode(diaryJson);
    List<Map<String, String>> diaries = rawList.map((e) => Map<String, String>.from(e)).toList();

    setState(() {
      _statusMessage = "正在构建向量索引 (耗时操作)...";
    });

    // 逐个索引日记
    for (int i = 0; i < diaries.length; i++) {
      final diary = diaries[i];
      await VectorStoreService.indexDiary(diary['date']!, diary['content']!);
      
      if (!mounted) return;
      setState(() {
        _progress = (i + 1) / diaries.length;
        _indexedCount = i + 1;
      });
    }

    // 完成后刷新
    await _loadStats();

    if (mounted) {
      setState(() {
        _isIndexing = false;
        _statusMessage = "索引构建完成！";
        _progress = 1.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("知识库构建完成")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("个人知识库"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text(
              "记忆突触连接中...",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "通过构建向量索引，AI 将能够“回忆”起您所有的过往日记，而不仅仅是最近几篇。这就好比从“金鱼记忆”升级为了“超级大脑”。",
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 30),
            
            // 统计卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("日记总数", "$_totalDiaries"),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildStatItem("已索引", "$_indexedCount"),
                ],
              ),
            ),

            const SizedBox(height: 40),

            if (_isIndexing) ...[
              LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey[200], color: Colors.blueAccent),
              const SizedBox(height: 10),
              Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _startIndexing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("开始构建 / 更新索引"),
                ),
              ),
              const SizedBox(height: 10),
              const Center(child: Text("首次构建可能需要几分钟，请保持网络通畅", style: TextStyle(fontSize: 12, color: Colors.grey))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}


