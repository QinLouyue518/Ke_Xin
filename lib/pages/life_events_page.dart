import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/life_event.dart';

class LifeEventsPage extends StatefulWidget {
  const LifeEventsPage({super.key});

  @override
  State<LifeEventsPage> createState() => _LifeEventsPageState();
}

class _LifeEventsPageState extends State<LifeEventsPage> {
  // final Color kMorandiBlue = const Color(0xFF7CA1B4); // 已废弃，改用 Theme
  List<LifeEvent> _lifeEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('life_events_data');
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        _lifeEvents = jsonList.map((e) => LifeEvent.fromJson(e)).toList();
        // Sort: ongoing first, then by startDate desc
        _lifeEvents.sort((a, b) {
          if (a.status == "ongoing" && b.status != "ongoing") return -1;
          if (a.status != "ongoing" && b.status == "ongoing") return 1;
          return b.startDate.compareTo(a.startDate);
        });
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_lifeEvents.map((e) => e.toJson()).toList());
    await prefs.setString('life_events_data', jsonString);
  }

  void _showAddEditDialog([LifeEvent? event]) {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController = TextEditingController(text: event?.description ?? '');
    DateTime selectedStartDate = event?.startDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(event == null ? "新增浮生册" : "编辑浮生册"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "册名", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: "描述", border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text("开始日期"),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedStartDate)),
                    trailing: const Icon(Icons.calendar_today),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          selectedStartDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isEmpty) return;

                  setState(() {
                    if (event == null) {
                      // Add new
                      _lifeEvents.add(LifeEvent(
                        id: const Uuid().v4(),
                        title: titleController.text,
                        description: descriptionController.text,
                        startDate: selectedStartDate,
                      ));
                    } else {
                      // Edit existing
                      int index = _lifeEvents.indexWhere((e) => e.id == event.id);
                      if (index != -1) {
                        _lifeEvents[index] = event.copyWith(
                          title: titleController.text,
                          description: descriptionController.text,
                          startDate: selectedStartDate,
                        );
                      }
                    }
                    // Re-sort
                     _lifeEvents.sort((a, b) {
                      if (a.status == "ongoing" && b.status != "ongoing") return -1;
                      if (a.status != "ongoing" && b.status == "ongoing") return 1;
                      return b.startDate.compareTo(a.startDate);
                    });
                  });
                  _saveData();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white), // ✨ 动态主题色
                child: const Text("保存"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventDiaries(LifeEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('diary_data');
    if (jsonString == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("暂无日记数据")));
      return;
    }

    final List<dynamic> allDiaries = jsonDecode(jsonString);
    List<Map<String, String>> eventDiaries = [];

    for (var diary in allDiaries) {
      if (event.diaryIds.contains(diary['date'])) {
        eventDiaries.add(Map<String, String>.from(diary));
      }
    }

    // Sort by date desc
    eventDiaries.sort((a, b) => b['date']!.compareTo(a['date']!));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text("📜 ${event.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text("${eventDiaries.length} 篇", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: eventDiaries.isEmpty 
                      ? const Center(child: Text("该事件下暂无日记", style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: eventDiaries.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final diary = eventDiaries[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(diary['date']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      const SizedBox(width: 8),
                                      Text(diary['mood_keyword'] ?? '', style: TextStyle(fontSize: 12, color: Colors.blueGrey[400])),
                                      const Spacer(),
                                      Text(diary['emoji'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(diary['content']!, style: const TextStyle(fontSize: 14, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _completeEvent(LifeEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("封存浮生册"),
        content: const Text("确定要封存这个浮生册吗？这将标记它为已完成状态。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () {
              setState(() {
                int index = _lifeEvents.indexWhere((e) => e.id == event.id);
                if (index != -1) {
                  _lifeEvents[index] = event.copyWith(
                    status: "completed",
                    endDate: DateTime.now(),
                  );
                  // Re-sort
                   _lifeEvents.sort((a, b) {
                    if (a.status == "ongoing" && b.status != "ongoing") return -1;
                    if (a.status != "ongoing" && b.status == "ongoing") return 1;
                    return b.startDate.compareTo(a.startDate);
                  });
                }
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text("确定封存"),
          ),
        ],
      ),
    );
  }
  
  void _deleteEvent(LifeEvent event) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("删除事件"),
        content: const Text("确定要删除这个事件吗？此操作无法撤销。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () {
              setState(() {
                _lifeEvents.removeWhere((e) => e.id == event.id);
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text("删除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor; // ✨ 获取主题色

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("浮生册", style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor)) // ✨ 动态色
          : _lifeEvents.isEmpty
              ? const Center(child: Text("还没有记录任何人生事件，点击右下角添加吧！", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lifeEvents.length,
                  itemBuilder: (context, index) {
                    final event = _lifeEvents[index];
                    final isOngoing = event.status == "ongoing";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isOngoing ? primaryColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2)), // ✨ 动态边框色
                      ),
                      color: isOngoing ? Colors.white : Colors.grey[50],
                      child: InkWell(
                        onTap: () => _showEventDiaries(event),
                        onDoubleTap: () => _showAddEditDialog(event),
                        onLongPress: () => _deleteEvent(event),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOngoing ? primaryColor.withOpacity(0.1) : Colors.grey[200], // ✨ 动态标签底色
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isOngoing ? "进行中" : "已封存",
                                      style: TextStyle(
                                        color: isOngoing ? primaryColor : Colors.grey, // ✨ 动态标签文字色
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isOngoing)
                                    TextButton.icon(
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: const Text("封存"),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.orange, // 封存按钮保留橙色以示警告，或者也可以改成 primaryColor
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _completeEvent(event),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isOngoing ? const Color(0xFF333333) : Colors.grey,
                                ),
                              ),
                              if (event.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  event.description,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${DateFormat('yyyy-MM-dd').format(event.startDate)} ${event.endDate != null ? '至 ${DateFormat('yyyy-MM-dd').format(event.endDate!)}' : '至今'}",
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.book, size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${event.diaryIds.length} 篇日记",
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: primaryColor, // ✨ 动态色
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

