import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'dart:async'; // ✨ 引入 Timer
import 'package:flutter_application_1/pages/diary_chat_page.dart';
// import 'package:sensors_plus/sensors_plus.dart'; // ✨ 移除 sensors_plus
import 'package:audioplayers/audioplayers.dart'; // ✨ 引入 audioplayers

class MemoryGalaxy extends StatefulWidget {
  final List<Map<String, String>> diaryEntries;
  final Function(Map<String, String>) onEntryUpdate;

  const MemoryGalaxy({
    super.key,
    required this.diaryEntries,
    required this.onEntryUpdate,
  });

  @override
  State<MemoryGalaxy> createState() => _MemoryGalaxyState();
}

class _MemoryGalaxyState extends State<MemoryGalaxy> with TickerProviderStateMixin {
  final Map<String, Offset> _starPositions = {};
  late AnimationController _controller; // ✨ 控制星尘动画
  
  // 情绪引力中心 (调整布局，使其更分散)
  final Map<String, Offset> _emotionCenters = {
    "开心": const Offset(1500, 600),
    "幸福": const Offset(1700, 500),
    "难过": const Offset(500, 1400),
    "沮丧": const Offset(300, 1600),
    "焦虑": const Offset(400, 400),
    "迷茫": const Offset(600, 300),
    "愤怒": const Offset(1600, 1600),
    "生气": const Offset(1700, 1500),
    "平静": const Offset(1000, 1000),
  };

  final Offset _defaultCenter = const Offset(1000, 1000);
  final double _canvasSize = 2000.0;
  
  // 缓存连线路径
  List<Offset> _sortedStarPoints = [];
  // ✨ 缓存排序后的日记 (用于星座连线匹配)
  List<Map<String, String>> _sortedEntries = [];
  // 缓存星尘粒子
  List<_StarDust> _dustParticles = [];
  // 缓存星星运动参数
  final Map<String, _StarMotion> _starMotions = {};

  // ✨ 岁月重塑播放控制
  int _playbackIndex = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;

  // ✨ 视口控制器 (用于初始居中)
  final TransformationController _transformationController = TransformationController();

  // ✨ 陀螺仪相关 (已移除)
  // StreamSubscription<GyroscopeEvent>? _sensorSubscription;
  // final ValueNotifier<Offset> _gyroOffsetNotifier = ValueNotifier(Offset.zero);

  // ✨ 音效播放器
  // 使用 AudioCache 预加载（旧版 API），或者在 audioplayers 6.x 中，即使是 AudioPlayer 也可以预热
  // 为了极致的低延迟，我们创建一个常驻的“预热池”
  final List<AudioPlayer> _playerPool = [];
  // ✨ 扩大池子：从 3 增加到 12。
  // 在日记较多、播放间隔较短（400ms）的情况下，3个播放器会导致复用冲突（上一个还没释放）。
  // 12 个播放器意味着每个播放器有 12 * 400ms = 4.8秒 的休息周期，远大于 1.2秒 的播放时长，绝对安全。
  final int _poolSize = 12; 
  int _poolIndex = 0;

  // ✨ 音效文件列表 (按卡农走向排序)
  // 1 -> C, 5 -> G, 6 -> A, 3 -> E, 4 -> F, 1 -> C, 4 -> F, 5 -> G
  final List<String> _canonMelody = [
    'sounds/1.C(do).mp3',  // 1
    'sounds/5.G(sol).mp3', // 5
    'sounds/6.A(la).mp3',  // 6
    'sounds/3.E(mi).mp3',  // 3
    'sounds/4.F(fa).mp3',  // 4
    'sounds/1.C(do).mp3',  // 1
    'sounds/4.F(fa).mp3',  // 4
    'sounds/5.G(sol).mp3', // 5
  ];

  @override
  void initState() {
    super.initState();
    
    // ✨ 预初始化播放器池，以此预热音频引擎
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop); // 播完后不循环，不释放，保持 stop 状态待命
      _playerPool.add(p);
    }

    // ✨ 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1), 
    )..repeat();
    
    _initDustParticles();
    _calculateStarPositions();
    _playbackIndex = _sortedEntries.length; 

    // ✨ 初始居中：等待第一帧布局完成后，移动视口到中心
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerView();
    });
  }

  void _centerView() {
    if (!mounted) return;
    // 获取屏幕尺寸
    final size = MediaQuery.of(context).size;
    // 画布中心
    const canvasCenter = Offset(1000, 1000);
    // 屏幕中心
    final screenCenter = Offset(size.width / 2, size.height / 2);
    
    // 计算偏移量：让画布中心 对齐 屏幕中心
    // 默认缩放比例为 1.0 (或者更小，如果是 minScale)
    const double initialScale = 0.5; // 稍微缩小一点，以便看到更多星星
    final offset = screenCenter - canvasCenter * initialScale;

    // 设置变换矩阵
    _transformationController.value = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(initialScale);
  }

  @override
  void dispose() {
    // _audioPlayer.dispose(); // 旧的单例
    // ✨ 销毁池子
    for (var p in _playerPool) {
      p.dispose();
    }
    _playbackTimer?.cancel();
    _controller.dispose();
    _transformationController.dispose();
    // _gyroOffsetNotifier.dispose(); // 移除
    super.dispose();
  }

  void _initDustParticles() {
    final random = Random();
    // ✨ 增加星尘数量：从 100 增加到 400，营造更丰富的深空氛围
    _dustParticles = List.generate(400, (index) {
      return _StarDust(
        position: Offset(
          random.nextDouble() * _canvasSize,
          random.nextDouble() * _canvasSize,
        ),
        size: random.nextDouble() * 2 + 0.5,
        opacity: random.nextDouble() * 0.5 + 0.1,
      );
    });
  }

  @override
  void didUpdateWidget(covariant MemoryGalaxy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diaryEntries != widget.diaryEntries) {
      _calculateStarPositions();
    }
  }

  void _calculateStarPositions() {
    final random = Random();
    _sortedStarPoints.clear();
    _sortedEntries.clear();
    
    // 先按时间排序，为了画连线
    var sortedList = List<Map<String, String>>.from(widget.diaryEntries);
    sortedList.sort((a, b) => a['date']!.compareTo(b['date']!));
    _sortedEntries = sortedList;

    for (var entry in _sortedEntries) {
      final key = '${entry['date']}_${entry['content']?.hashCode}';
      
      if (!_starPositions.containsKey(key)) {
        String mood = entry['mood_keyword'] ?? '平静';
        Offset center = _defaultCenter;
        
        // 模糊匹配
        for (var k in _emotionCenters.keys) {
          if (mood.contains(k)) {
            center = _emotionCenters[k]!;
            break;
          }
        }

        // 随机分布
        double angle = random.nextDouble() * 2 * pi;
        double distance = random.nextDouble() * 250; // 扩散半径
        
        _starPositions[key] = Offset(
          (center.dx + cos(angle) * distance).clamp(50.0, _canvasSize - 50.0),
          (center.dy + sin(angle) * distance).clamp(50.0, _canvasSize - 50.0),
        );
        
        // 初始化随机运动参数
        _starMotions[key] = _StarMotion(
          phase: random.nextDouble() * 2 * pi,
          radius: 3.0 + random.nextDouble() * 5.0, // ✨ 调整：恢复到适中的浮动半径 (3-8px)
          speed: 0.5 + random.nextDouble() * 1.0, 
        );
      }
      _sortedStarPoints.add(_starPositions[key]!);
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _playbackIndex = _sortedEntries.length; // 恢复显示全部
    });
  }

  void _startPlayback() {
    setState(() {
      _isPlaying = true;
      _playbackIndex = 0;
    });

    int totalStars = _sortedEntries.length;
    if (totalStars == 0) {
      _stopPlayback();
      return;
    }

    // 动态计算播放速度：总时长控制在 5-10 秒之间，根据星星数量动态调整
    // 至少每颗星 100ms，最快 30ms -> 调整为最快 100ms，给音频留出余量
    // 再次调整：用户反馈手机端偏快，进一步放慢节奏，区间设为 [800ms, 1500ms]
    int intervalMs = (20000 / totalStars).clamp(800, 1500).toInt();

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (_playbackIndex >= totalStars) {
        // 播放结束，稍微停顿一下再恢复交互状态
        timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isPlaying) {
             setState(() {
               _isPlaying = false;
             });
          }
        });
      } else {
        setState(() {
          _playbackIndex++;
        });
        // ✨ 在这里触发音效：每亮起一颗星星，播放一个随机音符
        if (_playbackIndex - 1 < _sortedEntries.length) {
           // 传入当前索引，实现旋律循环
           _playStarSound(_playbackIndex - 1);
        }
      }
    });
  }

  // ✨ 播放星星音效 (使用对象池优化延迟)
  Future<void> _playStarSound(int index) async {
    if (_canonMelody.isEmpty) return;
    
    // 按顺序循环取音符：卡农旋律
    final soundFile = _canonMelody[index % _canonMelody.length];
    
    try {
      // 1. 从池子里拿一个播放器 (轮询)
      final player = _playerPool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize; // 指针后移

      // 2. 立即设置资源并播放
      // ✨ 优化：不再 await stop()，直接 play。
      // 因为池子现在很大 (12)，轮到这个 player 时，它上一次的任务（1.2s后停止）肯定早就结束了。
      // 减少一次 stop 的异步调用，能显著降低“吞音”的概率。
      player.setVolume(0.6); // 不用 await
      await player.play(AssetSource(soundFile));
      
      // 3. 统一截断 (不销毁对象，只是 stop)
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) { 
          player.stop(); 
        }
      });
      
    } catch (e) {
      debugPrint("播放音效失败: $e");
    }
  }

  Color _getStarColor(String mood) {
    if (mood.contains("开心") || mood.contains("幸福")) return const Color(0xFFFFD700); // 金色
    if (mood.contains("难过") || mood.contains("沮丧")) return const Color(0xFF4FC3F7); // 冰蓝
    if (mood.contains("愤怒") || mood.contains("生气")) return const Color(0xFFFF5252); // 红色
    if (mood.contains("焦虑") || mood.contains("迷茫")) return const Color(0xFFE040FB); // 紫色
    if (mood.contains("平静")) return const Color(0xFF69F0AE); // 青色
    return Colors.white;
  }

  void _showStarDialog(Map<String, String> entry) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.95), // 深色背景
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: _getStarColor(entry['mood_keyword'] ?? '').withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 0,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry['date'] ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStarColor(entry['mood_keyword'] ?? '').withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStarColor(entry['mood_keyword'] ?? '').withOpacity(0.3)),
                    ),
                    child: Text(
                      entry['mood_keyword'] ?? '未知',
                      style: TextStyle(
                        color: _getStarColor(entry['mood_keyword'] ?? ''),
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                entry['content'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.8),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryChatPage(
                          entry: entry,
                          onUpdate: widget.onEntryUpdate,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text("唤醒记忆"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 星图层
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5, // 稍微扩大渐变范围
                colors: [
                  Color(0xFF0F1219), // 极深的蓝黑，几乎接近黑
                  Color(0xFF000000), // 纯黑边缘
                ],
              ),
            ),
            child: InteractiveViewer(
              transformationController: _transformationController, // ✨ 绑定控制器
              boundaryMargin: const EdgeInsets.all(1000),
              minScale: 0.2,
              maxScale: 3.0,
              constrained: false,
              child: SizedBox(
                width: _canvasSize,
                height: _canvasSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // ✨ 岁月重塑：根据播放进度筛选可见日记
                    final visibleEntries = _sortedEntries.take(_playbackIndex).toList();

                    // 计算当前帧的星星动态位置
                    final Map<String, Offset> currentPositions = {};
                    final List<Offset> currentPoints = [];

                    for (var entry in visibleEntries) {
                      final key = '${entry['date']}_${entry['content']?.hashCode}';
                      // 安全检查：防止数据不同步
                      if (!_starPositions.containsKey(key)) continue;

                      final base = _starPositions[key]!;
                      final motion = _starMotions[key]!;
                      
                      // 椭圆/圆形 轨道运动模拟
                      // ✨ 调优：系数降至 300 (原激进测试的一半)，配合缩小的半径，实现优雅的浮动
                      final double t = _controller.value * 2 * pi * motion.speed * 300 + motion.phase;
                      final dx = base.dx + cos(t) * motion.radius;
                      final dy = base.dy + sin(t) * motion.radius;
                      
                      final pos = Offset(dx, dy);
                      currentPositions[key] = pos;
                      currentPoints.add(pos);
                    }

                    // ✨ 这里的 Stack 是为了让 AnimatedBuilder 只包裹需要重绘的部分
                    
                    return Stack(
                      children: [
                        // 1. 背景绘制层 (连线 + 区域文字 + 星尘)
                        CustomPaint(
                          size: Size(_canvasSize, _canvasSize),
                          painter: _GalaxyPainter(
                            points: currentPoints,
                            emotionCenters: _emotionCenters,
                            dustParticles: _dustParticles,
                            animationValue: _controller.value,
                            diaryEntries: visibleEntries,
                          ),
                        ),

                        // 2. 星星层
                        ...visibleEntries.map((entry) {
                          final key = '${entry['date']}_${entry['content']?.hashCode}';
                          // 获取动态位置
                          final position = currentPositions[key] ?? _starPositions[key] ?? _defaultCenter;
                          
                          final double score = double.tryParse(entry['score'] ?? '50') ?? 50.0;
                          final double size = 12.0 + (score / 100.0) * 16.0; 
                          final Color color = _getStarColor(entry['mood_keyword'] ?? '');

                          return Positioned(
                            key: ValueKey(key),
                            left: position.dx - size / 2, // 原始坐标
                            top: position.dy - size / 2,
                            child: GestureDetector(
                              onTap: () {
                                _showStarDialog(entry);
                              },
                              child: _GlowingStar(
                                size: size,
                                color: color,
                                isNew: _isPlaying && entry == visibleEntries.last,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // 2. 播放时的日期指示器
          if (_isPlaying && _playbackIndex > 0 && _playbackIndex <= _sortedEntries.length)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    _sortedEntries[_playbackIndex - 1]['date'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            
          // ✨ 3. 岁月重塑按钮 (调整位置到左下角，避免遮挡)
          Positioned(
            left: 20,
            bottom: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlayback,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isPlaying ? "暂停回溯" : "岁月重塑",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDust {
  final Offset position;
  final double size;
  final double opacity;

  _StarDust({
    required this.position,
    required this.size,
    required this.opacity,
  });
}

class _StarMotion {
  final double phase;
  final double radius;
  final double speed;

  _StarMotion({required this.phase, required this.radius, required this.speed});
}

// ✨ 自定义绘制：背景连线、文字和星尘
class _GalaxyPainter extends CustomPainter {
  final List<Offset> points;
  final Map<String, Offset> emotionCenters;
  final List<_StarDust> dustParticles;
  final double animationValue; 
  final List<Map<String, String>> diaryEntries;

  _GalaxyPainter({
    required this.points,
    required this.emotionCenters,
    required this.dustParticles,
    required this.animationValue,
    required this.diaryEntries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0. ✨ 绘制星云背景 (优化：更柔和、多层次)
    // 使用 MaskFilter.blur 确实会让边缘模糊，但大面积绘制时可能还是显得生硬。
    // 我们改用 RadialGradient 来绘制每个星云，这样过渡会非常自然。
    
    emotionCenters.forEach((mood, center) {
      Color baseColor = Colors.white;
      if (mood.contains("开心") || mood.contains("幸福")) baseColor = const Color(0xFFFFD700);
      else if (mood.contains("难过") || mood.contains("沮丧")) baseColor = const Color(0xFF4FC3F7);
      else if (mood.contains("愤怒") || mood.contains("生气")) baseColor = const Color(0xFFFF5252);
      else if (mood.contains("焦虑") || mood.contains("迷茫")) baseColor = const Color(0xFFE040FB);
      else if (mood.contains("平静")) baseColor = const Color(0xFF69F0AE);
      
      // 让星云缓慢浮动
      double floatX = sin(animationValue * 2 * pi + mood.hashCode) * 40;
      double floatY = cos(animationValue * 2 * pi + mood.hashCode) * 40;
      Offset floatCenter = center + Offset(floatX, floatY);

      // 核心光晕 (较亮，较小) - 降低透明度 0.12 -> 0.08
      final corePaint = Paint()
        ..shader = RadialGradient(
          colors: [baseColor.withOpacity(0.08), baseColor.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: floatCenter, radius: 250));
      canvas.drawCircle(floatCenter, 250, corePaint);

      // 外围弥散 (极淡，极大) - 降低透明度 0.06 -> 0.04
      final outerPaint = Paint()
        ..shader = RadialGradient(
          colors: [baseColor.withOpacity(0.04), baseColor.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: floatCenter, radius: 500));
      canvas.drawCircle(floatCenter, 500, outerPaint);
    });

    // 1. 绘制星尘 (背景最底层)
    final dustPaint = Paint()..color = Colors.white;
    for (var dust in dustParticles) {
      // ✨ 让星尘轻微漂浮 (系数 30，极慢漂浮)
      double dx = dust.position.dx + sin(animationValue * 2 * pi * 30 + dust.opacity * 10) * 20;
      double dy = dust.position.dy + cos(animationValue * 2 * pi * 30 + dust.opacity * 10) * 20;
      
      // ✨ 增强可见性：提升不透明度上限，从 0.3 提升到 0.6
      dustPaint.color = Colors.white.withOpacity((dust.opacity * 0.5 + 0.1).clamp(0.0, 0.8));
      // ✨ 增强大小：让星尘颗粒稍微大一点点
      canvas.drawCircle(Offset(dx, dy), dust.size * 1.2, dustPaint);
    }

    // 2. 绘制时间连线 (弱化)
    final timeLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      
      for (int i = 0; i < points.length - 1; i++) {
        final p2 = points[i + 1];
        path.lineTo(p2.dx, p2.dy);
      }
      canvas.drawPath(path, timeLinePaint);
    }

    // 3. ✨ 绘制星座连线 (强关联) + 呼吸效果
    final constellationPaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 计算连线呼吸透明度 (0.1 ~ 0.3)
    double breathOpacity = 0.1 + sin(animationValue * 4 * pi) * 0.1 + 0.1;

    // 遍历所有星星对，寻找共鸣
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        // 距离优化：太远的不要连，避免画面杂乱
        // if ((points[i] - points[j]).distance > 300) continue; // ✨ 暂时移除距离限制，强制所有同情绪的都连上，测试效果

        final entryA = diaryEntries[i];
        final entryB = diaryEntries[j];
        
        // 核心匹配逻辑：同种情绪
        if (entryA['mood_keyword'] == entryB['mood_keyword'] && entryA['mood_keyword'] != null) {
           // 根据情绪给连线上色
           Color linkColor = Colors.white;
           if (entryA['mood_keyword']!.contains("开心")) linkColor = const Color(0xFFFFD700);
           else if (entryA['mood_keyword']!.contains("难过")) linkColor = const Color(0xFF4FC3F7);
           else if (entryA['mood_keyword']!.contains("愤怒")) linkColor = const Color(0xFFFF5252);
           
           // 应用呼吸透明度
           constellationPaint.color = linkColor.withOpacity(breathOpacity * 0.8); // 稍微调低一点基础透明度
           canvas.drawLine(points[i], points[j], constellationPaint);
        }
      }
    }

    // 4. 绘制区域文字
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.15),
      fontSize: 40,
      fontWeight: FontWeight.bold,
      letterSpacing: 4,
    );

    emotionCenters.forEach((name, offset) {
      final textSpan = TextSpan(text: name, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(offset.dx - textPainter.width / 2, offset.dy - textPainter.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) {
    return oldDelegate.points != points || 
           oldDelegate.dustParticles != dustParticles ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.diaryEntries != diaryEntries;
  }
}

// ✨ 单颗会呼吸的星星 (改为 Stateful 以控制入场动画)
class _GlowingStar extends StatefulWidget {
  final double size;
  final Color color;
  final bool isNew;

  const _GlowingStar({
    required this.size,
    required this.color,
    this.isNew = false,
  });

  @override
  State<_GlowingStar> createState() => _GlowingStarState();
}

class _GlowingStarState extends State<_GlowingStar> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // 如果是新出现的星星，初始透明度为0，然后渐显；否则直接显示
    _opacity = widget.isNew ? 0.0 : 1.0;
    
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _opacity = 1.0;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 1000), // 渐显时长
      curve: Curves.easeOutQuad,
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // 核心亮白
          boxShadow: [
            // 内层光晕
            BoxShadow(
              color: widget.color,
              blurRadius: widget.size,
              spreadRadius: 2,
            ),
            // 外层光晕
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: widget.size * 2,
              spreadRadius: widget.size,
            ),
          ],
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(reverse: true),
      ).scale(
         duration: Duration(milliseconds: 1500 + Random().nextInt(1000)), 
         begin: const Offset(0.9, 0.9),
         end: const Offset(1.1, 1.1),
         curve: Curves.easeInOut,
       ),
    );
  }
}