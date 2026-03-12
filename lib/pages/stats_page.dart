import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import '../services/api_settings_service.dart'; // ✨ 引入 API 配置服务

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  // 状态变量
  int _timeRangeDays = 7; // 7 或 30
  bool _isLoadingData = true;
  bool _isGeneratingReport = false;
  List<Map<String, dynamic>> _filteredEntries = []; // 用于折线图和报告（受时间范围限制）
  List<Map<String, dynamic>> _allEntries = []; // 用于日历（全部数据）
  Map<String, dynamic>? _aiReport;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 加载并筛选数据
  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('diary_data');
    
    // 尝试加载缓存的报告
    final String reportKey = 'stats_report_$_timeRangeDays';
    final String? cachedReport = prefs.getString(reportKey);
    if (cachedReport != null) {
      try {
        _aiReport = jsonDecode(cachedReport);
      } catch (e) {
        debugPrint("缓存报告解析失败: $e");
      }
    } else {
      _aiReport = null;
    }

    if (jsonString != null) {
      List<dynamic> list = jsonDecode(jsonString);
      
      // 解析数据
      List<Map<String, dynamic>> parsedList = [];
      for (var item in list) {
        try {
          // 解析日期
          DateTime date;
          if (item['date'].toString().contains('年')) {
             date = DateFormat('yyyy年M月d日', 'zh_CN').parse(item['date']);
          } else {
             date = DateTime.parse(item['date']);
          }
          
          // 解析分数
          int score = 50;
          if (item['score'] != null) {
            score = int.tryParse(item['score'].toString()) ?? 50;
          }

          parsedList.add({
            'date': date,
            'content': item['content'] ?? '',
            'score': score,
            'mood_keyword': item['mood_keyword'] ?? '',
            'raw_date': item['date'] // 保留原始日期字符串
          });
        } catch (e) {
          debugPrint("跳过解析失败的条目: $e");
        }
      }

      // 保存所有数据供日历使用
      _allEntries = List.from(parsedList);

      // 筛选最近 N 天
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final startDate = endOfToday.subtract(Duration(days: _timeRangeDays));

      var filtered = parsedList.where((e) {
        DateTime d = e['date'];
        return d.isAfter(startDate) && d.isBefore(endOfToday);
      }).toList();

      // 按日期升序排列 (用于画图)
      filtered.sort((a, b) => a['date'].compareTo(b['date']));
      
      _filteredEntries = filtered;
    }

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  // 切换时间范围
  void _onTimeRangeChanged(int days) {
    if (_timeRangeDays == days) return;
    setState(() {
      _timeRangeDays = days;
      _isLoadingData = true;
    });
    _loadData();
  }

  // 生成 AI 复盘
  Future<void> _generateAIReport() async {
    if (_filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("这段时间没有日记可供分析哦~")));
      return;
    }

    setState(() => _isGeneratingReport = true);

    // 从自定义配置读取 API 信息
    final apiKey = await ApiSettingsService.getApiKey();
    final apiUrl = await ApiSettingsService.getApiUrl();
    final modelName = await ApiSettingsService.getModelName();

    // 如果未配置 API Key，提示用户
    if (apiKey.isEmpty) {
      _showConfigRequiredDialog();
      setState(() => _isGeneratingReport = false);
      return;
    }

    try {
      // 构建 Prompt
      StringBuffer contentBuffer = StringBuffer();
      for (var entry in _filteredEntries) {
        contentBuffer.writeln("【${DateFormat('yyyy-MM-dd').format(entry['date'])}】 能量分:${entry['score']} 心情:${entry['mood_keyword']}");
        contentBuffer.writeln("内容: ${entry['content']}");
        contentBuffer.writeln("---");
      }

      final systemPrompt = """
你是一个能够深度洞察人心的心理分析师。
请阅读用户最近 ${_timeRangeDays} 天的日记，生成一份“时光切片”复盘报告。

**必须返回纯 JSON 格式**，结构如下：
{
  "keywords": ["关键词1", "关键词2", "关键词3", "关键词4", "关键词5"],
  "summary": "用一句温暖有力的话总结这段时光的主题（20字以内）",
  "analysis": "一段深度的心理分析。观察用户的情绪波动、关注点变化，并给出建设性的心理暗示或建议。（100-200字）"
}

请确保分析具有治愈感和洞察力。
""";

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
            {"role": "user", "content": contentBuffer.toString()}
          ],
          "temperature": 0.6,
          "response_format": {"type": "json_object"},
          // ✨ 启用推理功能（仅对 reasoner 模型有效）
          if (modelName.contains('reasoner') || modelName.contains('deepseek-r1'))
            "enable_thinking": true,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String? aiContent = data['choices']?[0]?['message']?['content'];
        
        if (aiContent != null) {
          // 清洗 markdown
          aiContent = aiContent.replaceAll('```json', '').replaceAll('```', '').trim();
          final reportJson = jsonDecode(aiContent);
          
          setState(() {
            _aiReport = reportJson;
          });

          // 缓存报告
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('stats_report_$_timeRangeDays', jsonEncode(reportJson));
        }
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("生成报告失败: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
      }
    }
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

  // 构建图表
  Widget _buildEnergyChart() {
    final primaryColor = Theme.of(context).primaryColor;

    if (_filteredEntries.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text("暂无数据", style: TextStyle(color: Colors.grey))));
    }

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var entry in _filteredEntries) {
      String dateStr = DateFormat('MM-dd').format(entry['date']);
      grouped.putIfAbsent(dateStr, () => []).add(entry);
    }
    
    List<FlSpot> spots = [];
    List<String> xLabels = [];
    List<Map<String, dynamic>> tooltipsData = [];
    
    int index = 0;
    
    for (var dateStr in grouped.keys) {
      var entries = grouped[dateStr]!;
      double avgScore = entries.map((e) => e['score'] as int).reduce((a, b) => a + b) / entries.length;
      spots.add(FlSpot(index.toDouble(), avgScore));
      xLabels.add(dateStr);
      String keywords = entries.map((e) => e['mood_keyword']).toSet().join("/");
      tooltipsData.add({
        "date": dateStr,
        "score": avgScore.toInt(),
        "keywords": keywords.isEmpty ? "日记" : keywords
      });
      index++;
    }

    return AspectRatio(
      aspectRatio: 1.70,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1, 
                  getTitlesWidget: (value, meta) {
                    int idx = value.toInt();
                    if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                    
                    if (_timeRangeDays == 30) {
                      if (idx % 5 != 0 && idx != xLabels.length - 1) return const SizedBox.shrink();
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        xLabels[idx],
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (xLabels.length - 1).toDouble(),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.5)]),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => Colors.white,
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final data = tooltipsData[barSpot.x.toInt()];
                    return LineTooltipItem(
                      "${data['date']}\n能量: ${data['score']}\n${data['keywords']}",
                      const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 计算更丰富的全谱颜色 (分数0-100渐变)
  Color _getGradientScoreColor(int score) {
    if (score < 0) score = 0;
    if (score > 100) score = 100;
    
    // 关键颜色节点：深蓝 -> 蓝 -> 绿 -> 黄 -> 橙 -> 红
    final List<Color> colors = [
      const Color(0xFF2C3E50), // 0: 深邃夜色 (低落)
      const Color(0xFF4A90E2), // 20: 忧郁蓝
      const Color(0xFF66BB6A), // 40: 平静绿
      const Color(0xFFFFEE58), // 60: 明亮黄
      const Color(0xFFFFA726), // 80: 活力橙
      const Color(0xFFFF5252), // 100: 热烈红
    ];

    // 计算区间
    double progress = score / 100.0;
    int sectionCount = colors.length - 1; // 5 个区间
    double sectionProgress = progress * sectionCount;
    int currentIndex = sectionProgress.floor();
    int nextIndex = (currentIndex + 1).clamp(0, sectionCount);
    double t = sectionProgress - currentIndex;

    return Color.lerp(colors[currentIndex], colors[nextIndex], t)!;
  }

  // 构建心情日历
  Widget _buildMoodCalendar() {
    // 将数据转为 Map<DateTime, int> (日期 -> 分数)
    Map<DateTime, int> dateScores = {};
    for (var entry in _allEntries) {
      DateTime date = DateTime(entry['date'].year, entry['date'].month, entry['date'].day);
      if (!dateScores.containsKey(date)) {
        dateScores[date] = entry['score'];
      }
    }

    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: DateTime.now(),
      locale: 'zh_CN',
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      // 移除默认间距
      rowHeight: 48,
      daysOfWeekHeight: 30,
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.zero, // ✨ 关键：移除间隙，让方格相连
        todayDecoration: BoxDecoration(), // 移除默认样式
        selectedDecoration: BoxDecoration(),
        defaultDecoration: BoxDecoration(),
        weekendDecoration: BoxDecoration(),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, dateScores);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, dateScores);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, dateScores, isToday: true);
        },
      ),
    );
  }

  Widget _buildDayCell(DateTime day, Map<DateTime, int> dateScores, {bool isToday = false}) {
    DateTime dateOnly = DateTime(day.year, day.month, day.day);
    int? currentScore = dateScores[dateOnly];
    
    // 如果没有日记，直接返回纯净的灰白方格
    if (currentScore == null) {
      return Container(
        margin: EdgeInsets.zero,
        transform: Matrix4.identity()..scale(1.01), 
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          // ❌ 移除外层方框，保持边缘纯净
        ),
        alignment: Alignment.center,
        child: Container(
          // ✨ 内部标注：深灰色圆环
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: isToday ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26, width: 1.5),
          ) : null,
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: Colors.grey[300], 
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }
    
    // --- 以下是有日记的处理逻辑 ---

    DateTime prevDay = dateOnly.subtract(const Duration(days: 1));
    DateTime nextDay = dateOnly.add(const Duration(days: 1));
    int? prevScore = dateScores[prevDay];
    int? nextScore = dateScores[nextDay];

    Color currentColor = _getGradientScoreColor(currentScore);
    
    Color leftColor = currentColor;
    if (prevScore != null) {
      leftColor = Color.lerp(_getGradientScoreColor(prevScore), currentColor, 0.5)!;
    }

    Color rightColor = currentColor;
    if (nextScore != null) {
      rightColor = Color.lerp(currentColor, _getGradientScoreColor(nextScore), 0.5)!;
    }

    return Container(
      margin: EdgeInsets.zero,
      transform: Matrix4.identity()..scale(1.02, 1.02), 
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [leftColor, currentColor, rightColor],
          stops: const [0.0, 0.5, 1.0], 
        ),
        // ❌ 移除外层方框
      ),
      alignment: Alignment.center,
      child: Container(
        // ✨ 内部标注：白色悬浮圆环
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: isToday ? BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 1))
          ]
        ) : null,
        child: Text(
          '${day.day}',
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 12,
            shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)],
          ),
        ),
      ),
    );
  }

  // 构建 AI 报告卡片
  Widget _buildAIReportCard() {
    final primaryColor = Theme.of(context).primaryColor;

    if (_isGeneratingReport) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text("AI 正在深度复盘...", style: TextStyle(color: primaryColor)),
          ],
        ),
      );
    }

    if (_aiReport == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                "生成一份本${_timeRangeDays == 7 ? '周' : '月'}的深度复盘",
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _generateAIReport,
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                label: const Text("立即生成报告"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final keywords = List<String>.from(_aiReport!['keywords'] ?? []);
    final summary = _aiReport!['summary'] ?? '';
    final analysis = _aiReport!['analysis'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: primaryColor),
              const SizedBox(width: 8),
              Text("AI 深度复盘", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                onPressed: _generateAIReport,
                tooltip: "重新生成",
              )
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords.map((k) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(k, style: TextStyle(fontSize: 12, color: primaryColor)),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Text(summary, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Text(analysis, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("光阴剪", style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingData 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 能量趋势板块
                Row(
                  children: [
                    const Text("能量趋势", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    // 时间范围选择
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 7, label: Text("7天")),
                        ButtonSegment(value: 30, label: Text("30天")),
                      ],
                      selected: {_timeRangeDays},
                      onSelectionChanged: (Set<int> newSelection) {
                        _onTimeRangeChanged(newSelection.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(MaterialState.selected)) return primaryColor;
                          return null;
                        }),
                        foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(MaterialState.selected)) return Colors.white;
                          return primaryColor;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: _buildEnergyChart(),
                ),
                
                const SizedBox(height: 32),

                // 2. 心情色谱板块
                const Text("心情色谱", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: _buildMoodCalendar(),
                ),
                const SizedBox(height: 16),
                // 图例
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildLegendDot(const Color(0xFF2C3E50), "0"),
                    _buildLegendDot(const Color(0xFF4A90E2), "20"),
                    _buildLegendDot(const Color(0xFF66BB6A), "40"),
                    _buildLegendDot(const Color(0xFFFFEE58), "60"),
                    _buildLegendDot(const Color(0xFFFFA726), "80"),
                    _buildLegendDot(const Color(0xFFFF5252), "100"),
                  ],
                ),

                const SizedBox(height: 32),
                
                // 3. AI 复盘报告板块
                _buildAIReportCard(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
