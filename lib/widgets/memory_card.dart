import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class MemoryCard extends StatefulWidget {
  final Map<String, String> entry;
  final VoidCallback onClose;

  const MemoryCard({super.key, required this.entry, required this.onClose});

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isCapturing = false;

  Future<void> _captureAndShare() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      // 等待一点时间，确保 UI 渲染完成
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // 提高 pixelRatio 以获得更高清的图片
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/memory_card.png').create();
      await file.writeAsBytes(pngBytes);

      final box = context.findRenderObject() as RenderBox?;
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '来自“刻心”的时光切片',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成分享图片失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final date = DateTime.tryParse(widget.entry['date'] ?? '') ?? DateTime.now();
    final weekDay = DateFormat('EEEE', 'zh_CN').format(date);
    final dateStr = DateFormat('yyyy.MM.dd').format(date);
    
    // 优先使用金句，如果没有则使用日记正文摘要
    String mainText = widget.entry['quote'] ?? '';
    bool isQuote = true;
    if (mainText.isEmpty) {
      mainText = widget.entry['content'] ?? '';
      if (mainText.length > 80) {
        mainText = "${mainText.substring(0, 80)}...";
      }
      isQuote = false;
    }

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      width: 320, // 设定一个固定的宽度，接近手机屏幕宽度
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. 顶部装饰区域
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.15),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -20, right: -20,
                                  child: Icon(Icons.format_quote, size: 100, color: primaryColor.withOpacity(0.1)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(weekDay, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                          const SizedBox(width: 12),
                                          Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.grey[600]), // 示例天气
                                          const SizedBox(width: 4),
                                          Text(widget.entry['mood_keyword'] ?? '平静', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // 2. 主体内容
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                            constraints: const BoxConstraints(minHeight: 200),
                            alignment: Alignment.center,
                            child: Text(
                              mainText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.8,
                                fontFamily: isQuote ? 'Serif' : null,
                                fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
                                color: const Color(0xFF333333),
                              ),
                            ),
                          ),

                          // 3. 底部信息
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text("刻", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text("刻心", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text("雕刻时光 · 铭记本心", style: TextStyle(fontSize: 10, color: Colors.grey[500], letterSpacing: 1)),
                                  ],
                                ),
                                const Spacer(),
                                QrImageView(
                                  data: 'https://github.com/your_repo/kexin', // 暂时放个占位链接
                                  version: QrVersions.auto,
                                  size: 50.0,
                                  gapless: false,
                                  foregroundColor: const Color(0xFF333333),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                        label: const Text("关闭"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: _isCapturing ? null : _captureAndShare,
                        icon: _isCapturing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.share),
                        label: Text(_isCapturing ? "生成中..." : "分享卡片"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

