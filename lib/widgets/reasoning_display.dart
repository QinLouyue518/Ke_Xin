import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 推理内容解析结果
class ReasoningResult {
  final String? reasoning;
  final String finalResponse;
  final bool hasReasoning;

  ReasoningResult({
    this.reasoning,
    required this.finalResponse,
    required this.hasReasoning,
  });

  /// 从 AI 返回的文本中解析推理过程
  static ReasoningResult parse(String text) {
    // 匹配 <think> 和 </think> 之间的内容（支持跨行，非贪婪匹配）
    final regex = RegExp(r'<think>\s*([\s\S]*?)\s*</think>', multiLine: true);
    final match = regex.firstMatch(text);

    if (match != null) {
      // 提取推理内容，清理多余空白
      final reasoning = match.group(1)?.trim() ?? '';
      // 移除 <think> 标签部分，获取最终回复
      final finalResponse = text.replaceAll(regex, '').trim();
      
      return ReasoningResult(
        reasoning: reasoning,
        finalResponse: finalResponse,
        hasReasoning: reasoning.isNotEmpty,
      );
    }

    // 没有推理标签，返回原文
    return ReasoningResult(
      finalResponse: text,
      hasReasoning: false,
    );
  }
}

/// 可折叠的推理显示组件
class ReasoningDisplay extends StatefulWidget {
  final String reasoningText;
  final Duration animationDuration;

  const ReasoningDisplay({
    super.key,
    required this.reasoningText,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<ReasoningDisplay> createState() => _ReasoningDisplayState();
}

class _ReasoningDisplayState extends State<ReasoningDisplay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // 极浅的灰色背景
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 可点击的标题栏
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text(
                    '思考过程',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B), // 浅灰色字体
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 展开的内容区域
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.reasoningText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8), // 更浅的灰色字体
                    height: 1.6,
                  ),
                ),
              ),
            )
            .animate(
              onPlay: (controller) => controller.forward(),
            )
            .fadeIn(duration: widget.animationDuration)
            .slideY(
              begin: -0.1,
              end: 0,
              duration: widget.animationDuration,
              curve: Curves.easeOut,
            ),
        ],
      ),
    );
  }
}
