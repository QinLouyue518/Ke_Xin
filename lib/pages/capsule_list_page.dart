import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/capsule.dart';
import 'capsule_editor_page.dart';

class CapsuleListPage extends StatefulWidget {
  const CapsuleListPage({super.key});

  @override
  State<CapsuleListPage> createState() => _CapsuleListPageState();
}

class _CapsuleListPageState extends State<CapsuleListPage> {
  List<Capsule> _capsules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCapsules();
  }

  Future<void> _loadCapsules() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final String? capsulesJson = prefs.getString('capsules_data');

    if (capsulesJson != null && capsulesJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(capsulesJson);
        setState(() {
          _capsules = decoded
              .map((e) => Capsule.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _capsules.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      } catch (e) {
        debugPrint('加载闪念失败：$e');
        setState(() {
          _capsules = [];
        });
      }
    } else {
      setState(() {
        _capsules = [];
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveCapsules() async {
    final prefs = await SharedPreferences.getInstance();
    final String capsulesJson = jsonEncode(
      _capsules.map((c) => c.toJson()).toList(),
    );
    await prefs.setString('capsules_data', capsulesJson);
  }

  void _addCapsule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CapsuleEditorPage(),
      ),
    );

    if (result != null && result is String && result.trim().isNotEmpty) {
      final newCapsule = Capsule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: result.trim(),
        createdAt: DateTime.now(),
      );

      setState(() {
        _capsules.insert(0, newCapsule);
      });
      await _saveCapsules();
    }
  }

  void _deleteCapsule(Capsule capsule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除闪念'),
        content: const Text('确定要删除这条闪念吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _capsules.removeWhere((c) => c.id == capsule.id);
      });
      await _saveCapsules();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('闪念已删除')),
        );
      }
    }
  }

  void _copyContent(Capsule capsule) async {
    await Clipboard.setData(ClipboardData(text: capsule.content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('思想闪念', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于闪念',
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _capsules.isEmpty
              ? _buildEmptyState(primaryColor)
              : _buildCapsuleList(primaryColor),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCapsule,
        icon: const Icon(Icons.add),
        label: const Text('新闪念'),
        backgroundColor: primaryColor,
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 80,
            color: primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有闪念',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '记录零碎的想法、瞬间的感悟\n它们会在写日记时成为你的灵感',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addCapsule,
            icon: const Icon(Icons.add),
            label: const Text('创建第一个闪念'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleList(Color primaryColor) {
    return RefreshIndicator(
      onRefresh: _loadCapsules,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _capsules.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final capsule = _capsules[index];
          return _buildCapsuleCard(capsule, primaryColor);
        },
      ),
    );
  }

  Widget _buildCapsuleCard(Capsule capsule, Color primaryColor) {
    return Dismissible(
      key: Key(capsule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除闪念'),
            content: const Text('确定要删除这条闪念吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return confirmed == true;
      },
      onDismissed: (direction) async {
        setState(() {
          _capsules.removeWhere((c) => c.id == capsule.id);
        });
        await _saveCapsules();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('闪念已删除')),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _copyContent(capsule),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDateTime(capsule.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showMoreOptions(capsule),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    capsule.content,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(Capsule capsule) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制内容'),
              onTap: () {
                Navigator.pop(context);
                _copyContent(capsule);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除闪念', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteCapsule(capsule);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于思想闪念'),
        content: const Text(
          '闪念是用来记录零碎思想和情感的轻量工具。\n\n'
          '• 快速记录一闪而过的想法\n'
          '• 捕捉瞬间的情绪和感悟\n'
          '• 不会被 AI 分析，只为你保存\n'
          '• 写日记时可以参考这些闪念\n\n'
          '让每一个细微的念头都有处安放。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
