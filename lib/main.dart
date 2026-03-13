import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✨ 引入 localizations
import 'package:provider/provider.dart'; // ✨ 引入 provider
import 'package:flutter_application_1/theme_provider.dart'; // ✨ 引入 theme_provider
import 'package:flutter_application_1/pages/settings_page.dart'; // ✨ 引入 settings_page
import 'package:flutter_application_1/pages/api_config_page.dart'; // ✨ 引入 API 配置页面
import 'package:flutter_application_1/write_diary_page.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_application_1/pages/diary_reader_page.dart'; // ✨ 引入新阅读页
import 'package:flutter_application_1/pages/user_profile_page.dart';
import 'package:flutter_application_1/pages/global_chat_page.dart';
import 'package:flutter_application_1/pages/stats_page.dart';
import 'package:flutter_application_1/pages/life_events_page.dart'; // 引入 LifeEventsPage
import 'package:flutter_application_1/models/life_event.dart'; // 引入 LifeEvent 模型
import 'package:flutter_application_1/widgets/memory_galaxy.dart'; // 引入 MemoryGalaxy
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_application_1/pages/chronicle_page.dart'; // 引入 ChroniclePage
import 'package:flutter_application_1/services/vector_store_service.dart'; // ✨ 引入向量存储服务
import 'package:flutter_application_1/services/background_settings_service.dart'; // ✨ 引入背景设置服务
import 'package:flutter_application_1/services/card_style_settings_service.dart'; // ✨ 引入卡片样式设置服务
import 'package:flutter_application_1/pages/capsule_list_page.dart'; // ✨ 引入胶囊页面

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("注意：未找到 .env 文件");
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // ✨ 获取当前主题
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: '刻心',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [ // ✨ 本地化代理配置
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [ // ✨ 支持的语言
        Locale('zh', 'CN'), // 中文简体
      ],
      locale: const Locale('zh', 'CN'), // ✨ 强制使用中文
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.themeColor, // ✨ 使用动态颜色
          brightness: Brightness.light,
          surface: const Color(0xFFF9FAFB),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 15, height: 1.6, letterSpacing: 0.5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          iconTheme: IconThemeData(color: Colors.black54),
        ),
      ),
      home: const MyHomePage(),
      routes: {
        '/api-config': (context) => const ApiConfigPage(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Map<String, String>> _diaryEntries = [];
  List<LifeEvent> _allLifeEvents = []; // ✨ 缓存所有事件数据
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isGalaxyView = false; // ✨ 星图/列表视图切换开关
  bool _isLoading = true;
  
  // ✨ 背景设置相关
  File? _backgroundImage;
  double _backgroundBlur = 5.0;
  bool _isBackgroundEnabled = false;
  
  // ✨ 卡片样式设置相关
  Color _cardColor = CardStyleSettingsService.defaultCardColor;
  double _cardOpacity = CardStyleSettingsService.defaultOpacity;
  bool _isCardStyleEnabled = false;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
    _loadBackgroundSettings();
    _loadCardStyleSettings();
  }

  Future<void> _loadBackgroundSettings() async {
    debugPrint('开始加载背景设置...');
    final settings = await BackgroundSettingsService.getAllSettings();
    debugPrint('背景设置：$settings');
    if (mounted) {
      setState(() {
        _backgroundBlur = settings['blur'] as double;
        _isBackgroundEnabled = settings['enabled'] as bool;
        final path = settings['path'] as String?;
        debugPrint('背景图片路径：$path');
        if (path != null && path.isNotEmpty) {
          _backgroundImage = File(path);
          debugPrint('背景图片文件已加载：${_backgroundImage!.path}');
        } else {
          debugPrint('未找到背景图片路径');
        }
      });
    }
  }
  
  Future<void> _loadCardStyleSettings() async {
    debugPrint('开始加载卡片样式设置...');
    final settings = await CardStyleSettingsService.getAllSettings();
    debugPrint('卡片样式设置：$settings');
    if (mounted) {
      setState(() {
        _cardColor = Color(settings['color'] as int);
        _cardOpacity = settings['opacity'] as double;
        _isCardStyleEnabled = settings['enabled'] as bool;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('diary_data', jsonEncode(_diaryEntries));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // ✨ 加载人生事件数据
    final String? eventsJson = prefs.getString('life_events_data');
    if (eventsJson != null) {
      final List<dynamic> list = jsonDecode(eventsJson);
      if (mounted) {
        setState(() {
          _allLifeEvents = list.map((e) => LifeEvent.fromJson(e)).toList();
        });
      }
    }

    final jsonString = prefs.getString('diary_data');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<Map<String, String>> entries = await Future(() {
          final List<dynamic> decodedList = jsonDecode(jsonString);
          // ✅ 核心修复：使用更安全的类型转换，防止因某些字段类型不对（如 int vs String）导致崩溃
          List<Map<String, String>> tempList = decodedList.map((item) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(item);
            return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
          }).toList();
          
          for (var entry in tempList) {
            if (entry['date']!.contains('年')) {
              try {
                DateTime parsedDate = DateFormat('yyyy年M月d日', 'zh_CN').parse(entry['date']!);
                entry['date'] = DateFormat('yyyy-MM-dd').format(parsedDate);
              } catch (e) {
                entry['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
              }
            }
          }
          
          tempList.sort((a, b) => b['date']!.compareTo(a['date']!));
          return tempList;
        });
        if (mounted) {
          setState(() {
            _diaryEntries = entries;
            _isLoading = false;
          });
          _saveData();
        }
      } catch (e) {
        debugPrint("Error loading diary data: $e");
        // 即使出错，也要停止加载状态，避免转圈
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    String dateString = DateFormat('yyyy-MM-dd').format(day);
    return _diaryEntries.where((entry) => entry['date'] == dateString).toList();
  }
  
  Future<void> _showAddToEventDialog(Map<String, String> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('life_events_data');
    if (jsonString == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("暂无进行中的人生事件，请先去创建")));
      return;
    }

    final List<dynamic> jsonList = jsonDecode(jsonString);
    List<LifeEvent> events = jsonList.map((e) => LifeEvent.fromJson(e)).toList();
    List<LifeEvent> ongoingEvents = events.where((e) => e.status == "ongoing").toList();

    if (ongoingEvents.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("暂无进行中的人生事件，请先去创建")));
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("添加到浮生册", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...ongoingEvents.map((event) {
                final bool isAlreadyAdded = event.diaryIds.contains(entry['date']);
                return ListTile(
                  title: Text(event.title),
                  subtitle: Text(event.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: isAlreadyAdded 
                      ? const Icon(Icons.check_circle, color: Colors.green) 
                      : const Icon(Icons.add_circle_outline),
                  onTap: () async {
                    if (isAlreadyAdded) {
                       Navigator.pop(context);
                       return;
                    }

                    // Update event
                    final int eventIndex = events.indexWhere((e) => e.id == event.id);
                    if (eventIndex != -1) {
                      List<String> newIds = List.from(event.diaryIds)..add(entry['date']!);
                      events[eventIndex] = event.copyWith(diaryIds: newIds);
                      
                      // Save
                      final String newJsonString = jsonEncode(events.map((e) => e.toJson()).toList());
                      await prefs.setString('life_events_data', newJsonString);
                      
                      // ✨ 实时更新首页的 _allLifeEvents 数据
                      if (mounted) {
                        setState(() {
                          _allLifeEvents = events;
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已将日记添加到事件：${event.title}")));
                        }
                      }
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ✨ 查找日记所属的事件名称
  List<String> _getEventNamesForDiary(String date) {
    return _allLifeEvents
        .where((e) => e.diaryIds.contains(date))
        .map((e) => e.title)
        .toList();
  }

  void _scrollToDate(DateTime date) {
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    int index = _diaryEntries.indexWhere((entry) => entry['date'] == dateString);
    if (index != -1) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        alignment: 0,
      );
    }
  }

  void _showCalendarPanel() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false, initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: TableCalendar(
                            locale: 'zh_CN', firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay, selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            eventLoader: _getEventsForDay,
                            onDaySelected: (selectedDay, focusedDay) {
                              setModalState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                              Navigator.pop(context);
                              _scrollToDate(selectedDay);
                              setState(() {});
                            },
                            calendarStyle: CalendarStyle(
                              selectedDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                              todayDecoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.5), shape: BoxShape.circle),
                              markerDecoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.7), shape: BoxShape.circle),
                            ),
                            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 5, padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          color: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: const SizedBox(height: 120),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.5));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('构建主界面，背景状态：enabled=$_isBackgroundEnabled, image=${_backgroundImage != null}, blur=$_backgroundBlur');
    return Scaffold(
      extendBodyBehindAppBar: true,
      // ✨ 自定义背景
      body: Stack(
        children: [
          // 背景图片层
          if (_backgroundImage != null && _isBackgroundEnabled)
            Positioned.fill(
              child: Image.file(
                _backgroundImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('背景图片加载失败：$error');
                  return Container(color: Colors.grey[200]);
                },
              ),
            ),
          // 虚化效果层
          if (_backgroundImage != null && _isBackgroundEnabled && _backgroundBlur > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _backgroundBlur, sigmaY: _backgroundBlur),
                child: Container(color: Colors.transparent),
              ),
            ),
          // 内容层
          _buildMainContent(),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
        child: Column(
          children: [
            // ✨ 抽屉头部
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "刻心",
                      style: TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF333333),
                        letterSpacing: 4,
                        fontFamily: 'Serif', // 使用衬线体增加文学感
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "雕刻时光 · 铭记本心",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], letterSpacing: 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ✨ 功能列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  ListTile(
                    leading: Icon(Icons.event_note, color: Theme.of(context).primaryColor), // ✨ 动态主题色
                    title: const Text("浮生册", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("人生剧本 · 事件管理", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LifeEventsPage()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.bar_chart_rounded, color: Theme.of(context).primaryColor), // ✨ 动态主题色
                    title: const Text("光阴剪", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("时光切片 · 数据统计", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StatsPage()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.chat_bubble_outline_rounded, color: Theme.of(context).primaryColor), // ✨ 动态主题色
                    title: const Text("清言客", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("AI 伴侣 · 自由对话", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const GlobalChatPage()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.account_circle_outlined, color: Theme.of(context).primaryColor), // ✨ 动态主题色
                    title: const Text("素心鉴", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("我的画像 · 人格分析", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfilePage()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.history_edu, color: Theme.of(context).primaryColor), // ✨ 动态主题色
                    title: const Text("流年史官", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("数字孪生 · 自传连载", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ChroniclePage()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.auto_awesome_outlined, color: Theme.of(context).primaryColor), // ✨ 动态主题色
                    title: const Text("思想闪念", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("零碎思想 · 情感碎片", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CapsuleListPage()));
                    },
                  ),
                  const Divider(height: 30, indent: 20, endIndent: 20),
                  // ✨ 新增设置选项
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Colors.grey),
                    title: const Text("设置", style: TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                      // 从设置页面返回时，重新加载背景设置和卡片样式设置
                      _loadBackgroundSettings();
                      _loadCardStyleSettings();
                    },
                  ),
                ],
              ),
            ),
            // 底部留白 (移除版本号)
            const SizedBox(height: 24),
          ],
        ),
      ),
      appBar: AppBar(
        // ✨ 左侧不再默认显示返回箭头，而是汉堡菜单（由 Drawer 自动处理）
        // 如果想自定义图标，可以使用 leading 属性，但默认的就很好看
        title: GestureDetector(
          onTap: _showCalendarPanel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('yyyy年 M月').format(_focusedDay), style: const TextStyle(fontSize: 18, color: Color(0xFF333333))),
              const Icon(Icons.arrow_drop_down_rounded, size: 32, color: Color(0xFF333333)),
            ],
          ),
        ),
        actions: [
          // ✨ 仅保留核心的视图切换按钮
          IconButton(
            icon: Icon(
              _isGalaxyView ? Icons.view_list_rounded : Icons.auto_awesome_mosaic_rounded,
              color: const Color(0xFF333333),
            ),
            tooltip: _isGalaxyView ? "列表视图" : "记忆星图",
            onPressed: () {
              setState(() {
                _isGalaxyView = !_isGalaxyView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const WriteDiaryPage()));
          if (result != null && mounted) {
            final newEntry = result as Map<String, dynamic>;
            setState(() {
              _diaryEntries.insert(0, newEntry as Map<String, String>);
              _diaryEntries.sort((a, b) => b['date']!.compareTo(a['date']!));
              _selectedDay = DateTime.now();
              _focusedDay = DateTime.now();
              _isLoading = false;
            });
            await _saveData();

            // ✨ 自动索引新日记到知识库
            VectorStoreService.indexDiary(newEntry['date']!, newEntry['content']!);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('写日记'),
      ),
    );
  }

  // ✨ 构建主内容区域（带背景光晕效果）
  Widget _buildMainContent() {
    return Stack(
      children: [
        // 背景光晕装饰（保留原有的动画光晕效果）
        if (!_isGalaxyView) ...[
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 4.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
          ),
          Positioned(
            bottom: 50,
            left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 5.seconds, delay: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
          ),
        ],
        SafeArea(
          child: _isLoading
              ? _buildShimmerList()
              : _diaryEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text("纸短情长，记录当下", style: TextStyle(color: Colors.grey[400], fontSize: 16, letterSpacing: 1.5)),
                        ],
                      ),
                    )
                  : _isGalaxyView
                      ? MemoryGalaxy(
                          diaryEntries: _diaryEntries,
                          onEntryUpdate: (updatedEntry) {
                            int index = _diaryEntries.indexWhere((e) => e['date'] == updatedEntry['date']);
                            if (index != -1) {
                              setState(() {
                                _diaryEntries[index] = updatedEntry;
                              });
                              _saveData();
                            }
                          },
                        )
                      : ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          itemCount: _diaryEntries.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemBuilder: (context, index) {
                            final entry = _diaryEntries[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryReaderPage(
                                  entry: entry,
                                  onUpdate: (updatedEntry) {
                                    setState(() {
                                      _diaryEntries[index] = updatedEntry;
                                    });
                                    _saveData();
                                  },
                                  onDelete: () {
                                    setState(() {
                                      _diaryEntries.removeAt(index);
                                    });
                                    _saveData();
                                  },
                                  onAddToEvent: () => _showAddToEventDialog(entry),
                                )));
                              },
                              child: Card(
                                color: (_isCardStyleEnabled ? _cardColor : Colors.white).withValues(alpha: _isCardStyleEnabled ? _cardOpacity : 0.9),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                                  side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
                                ),
                                margin: const EdgeInsets.only(bottom: 16.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Hero(
                                            tag: 'date_${entry['date']}',
                                            child: Material(
                                              color: Colors.transparent,
                                              child: Text(
                                                DateFormat('M 月 d 日').format(DateTime.parse(entry['date']!)),
                                                style: const TextStyle(fontSize: 16, color: Color(0xFF555555), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                            child: Text(entry['mood_keyword'] ?? '日记', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor)),
                                          ),
                                          const Spacer(),
                                          Text(entry['emoji'] ?? '😐', style: const TextStyle(fontSize: 24.0)),
                                        ],
                                      ),
                                      const SizedBox(height: 12.0),
                                      Hero(
                                        tag: 'content_${entry['date']}',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Text(
                                            entry['content']!,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 15.0, height: 1.6, color: Color(0xFF555555)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (_getEventNamesForDiary(entry['date']!).isNotEmpty)
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: _getEventNamesForDiary(entry['date']!).map((eventName) =>
                                              Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Text(
                                                  "#$eventName",
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[400])
                                                ),
                                              )
                                            ).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}