import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/pages/diary_chat_page.dart'; // 引入对话页
import 'package:flutter_application_1/write_diary_page.dart'; // 引入编辑页
import 'package:flutter_application_1/widgets/memory_card.dart'; // 引入拾光签

// 纸张色常量
const Color kPaperColor = Color(0xFFFDFBF7);

class DiaryReaderPage extends StatefulWidget {
  final Map<String, String> entry;
  final Function(Map<String, String>) onUpdate; // 回调更新数据
  final VoidCallback onDelete; // 回调删除
  final VoidCallback onAddToEvent; // ✨ 新增：添加到事件的回调

  const DiaryReaderPage({
    super.key,
    required this.entry,
    required this.onUpdate,
    required this.onDelete,
    required this.onAddToEvent,
  });

  @override
  State<DiaryReaderPage> createState() => _DiaryReaderPageState();
}

class _DiaryReaderPageState extends State<DiaryReaderPage> {
  late ScrollController _scrollController;
  bool _showMenu = true; // 默认进入显示菜单
  late Map<String, String> _currentEntry; // ✨ 新增：本地存储当前条目以支持即时更新

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentEntry = widget.entry; // 初始化本地状态
    // 自动隐藏菜单
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showMenu = false);
    });
  }

  void _editDiary() async {
    final newEntry = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteDiaryPage(existingEntry: _currentEntry),
      ),
    );
    if (newEntry != null) {
      setState(() {
        _currentEntry = Map<String, String>.from(newEntry);
      });
      widget.onUpdate(_currentEntry);
    }
  }

  void _showMemoryCard() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "MemoryCard",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: MemoryCard(
              entry: _currentEntry,
              onClose: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final date = DateTime.parse(_currentEntry['date']!);
    
    return Scaffold(
      backgroundColor: kPaperColor,
      body: Stack(
        children: [
          // 1. 阅读层
          GestureDetector(
            onTap: () => setState(() => _showMenu = !_showMenu),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: const SizedBox(height: 100)), // 顶部留白
                
                // 标题与日期
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'date_${_currentEntry['date']}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              DateFormat('M月d日').format(date),
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold, 
                                color: theme.themeColor,
                                fontFamily: 'Serif'
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${DateFormat('yyyy').format(date)} · ${DateFormat('EEEE', 'zh_CN').format(date)}",
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        // 心情与能量
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_currentEntry['emoji'] ?? '😐', style: const TextStyle(fontSize: 24)),
                            if (_currentEntry['mood_keyword'] != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.themeColor.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_currentEntry['mood_keyword']!, style: TextStyle(fontSize: 12, color: theme.themeColor)),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // 正文内容
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Hero(
                      tag: 'content_${_currentEntry['date']}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          _currentEntry['content'] ?? '',
                          style: const TextStyle(
                            fontSize: 17, 
                            height: 1.8, 
                            color: Color(0xFF2D2D2D),
                            fontFamily: 'Serif',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // AI 点评与引用 (如果有)
                if (_currentEntry.containsKey('comment') || _currentEntry.containsKey('quote'))
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const Divider(height: 40),
                          if (_currentEntry['quote'] != null && _currentEntry['quote']!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  Text("❝ ${_currentEntry['quote']} ❞", 
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700], fontFamily: 'Serif')
                                  ),
                                  if (_currentEntry['advice'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(_currentEntry['advice']!, style: TextStyle(fontSize: 12, color: theme.themeColor)),
                                    )
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 16),
                          
                          if (_currentEntry['comment'] != null && _currentEntry['comment']!.isNotEmpty)
                             Text(
                               "AI 寄语：${_currentEntry['comment']}",
                               style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                             )
                        ],
                      ),
                    ),
                  ),
                  
                SliverToBoxAdapter(child: const SizedBox(height: 100)), // 底部留白
              ],
            ),
          ),

          // 2. 顶部导航栏 (仅保留删除)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showMenu ? 0 : -80,
            left: 0, right: 0,
            child: AppBar(
              backgroundColor: kPaperColor.withValues(alpha: 0.95),
              elevation: 0,
              leading: const BackButton(color: Colors.black87),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.black54),
                  onPressed: () {
                    // 删除确认逻辑
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除日记'),
                        content: const Text('确定要删除这条回忆吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          TextButton(onPressed: () {
                             widget.onDelete();
                             Navigator.pop(ctx);
                             Navigator.pop(context);
                          }, child: const Text('删除', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          
          // 3. 底部操作栏 (收纳所有功能，降低高度)
          AnimatedPositioned(
             duration: const Duration(milliseconds: 200),
             bottom: _showMenu ? 0 : -100,
             left: 0, right: 0,
             child: Container(
               color: kPaperColor.withValues(alpha: 0.95),
               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // 降低垂直 padding
               child: SafeArea(
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceAround,
                   children: [
                     _ActionButton(
                       icon: Icons.chat_bubble_outline, 
                       label: "对话", 
                       onTap: () async {
                         // 跳转到 DiaryChatPage
                         await Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryChatPage(
                           entry: _currentEntry,
                           onUpdate: (updatedEntry) {
                             setState(() {
                               _currentEntry = updatedEntry;
                             });
                             widget.onUpdate(updatedEntry);
                           },
                         )));
                       }
                     ),
                     _ActionButton(
                       icon: Icons.edit_note_outlined, 
                       label: "修改", 
                       onTap: _editDiary,
                     ),
                     _ActionButton(
                       icon: Icons.bookmark_add_outlined, 
                       label: "收藏", 
                       onTap: widget.onAddToEvent, 
                     ),
                     _ActionButton(
                       icon: Icons.share_outlined, 
                       label: "分享", 
                       onTap: _showMemoryCard,
                     ),
                   ],
                 ),
               ),
             ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
    );
  }
}

