import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../life_stage.dart';
import '../time_service.dart';

class LifeStagesPage extends StatefulWidget {
  const LifeStagesPage({super.key});

  @override
  State<LifeStagesPage> createState() => _LifeStagesPageState();
}

class _LifeStagesPageState extends State<LifeStagesPage> {
  List<LifeStage> _stages = [];
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadLifeStages();
  }

  Future<void> _loadLifeStages() async {
    _stages = await TimeService.loadLifeStages();
    setState(() {});
  }

  Future<void> _saveLifeStages() async {
    await TimeService.saveLifeStages(_stages);
    setState(() {});
  }

  void _showEditDialog({LifeStage? stage}) {
    final isEditing = stage != null;
    final TextEditingController nameController = TextEditingController(text: stage?.name ?? '');
    DateTime startDate = stage?.startDate ?? DateTime.now();
    DateTime endDate = stage?.endDate ?? DateTime.now().add(const Duration(days: 365));
    List<String> tags = List.from(stage?.tags ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? '编辑人生阶段' : '添加人生阶段'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '阶段名称'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('开始日期: ${DateFormat('yyyy-MM-dd').format(startDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() { startDate = picked; });
                      }
                    },
                  ),
                  ListTile(
                    title: Text('结束日期: ${DateFormat('yyyy-MM-dd').format(endDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() { endDate = picked; });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(labelText: '标签 (逗号分隔)'),
                    onChanged: (value) {
                      tags = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    },
                    controller: TextEditingController(text: tags.join(', ')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('阶段名称不能为空')));
                    return;
                  }
                  final newStage = LifeStage(
                    id: stage?.id ?? _uuid.v4(),
                    name: nameController.text.trim(),
                    startDate: startDate,
                    endDate: endDate,
                    tags: tags,
                  );

                  if (isEditing) {
                    final index = _stages.indexWhere((s) => s.id == newStage.id);
                    if (index != -1) {
                      _stages[index] = newStage;
                    }
                  } else {
                    _stages.add(newStage);
                  }
                  await _saveLifeStages();
                  Navigator.pop(context);
                },
                child: Text(isEditing ? '保存' : '添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteStage(LifeStage stage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除人生阶段'),
        content: Text('确定要删除阶段 "${stage.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              _stages.removeWhere((s) => s.id == stage.id);
              await _saveLifeStages();
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('人生阶段管理'),
        centerTitle: true,
      ),
      body: _stages.isEmpty
          ? const Center(
              child: Text('暂无人生阶段，点击右下角按钮添加', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _stages.length,
              itemBuilder: (context, index) {
                final stage = _stages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ListTile(
                    title: Text(stage.name),
                    subtitle: Text(
                      '${DateFormat('yyyy-MM-dd').format(stage.startDate)} - ${DateFormat('yyyy-MM-dd').format(stage.endDate)}'
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditDialog(stage: stage),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _confirmDeleteStage(stage),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
