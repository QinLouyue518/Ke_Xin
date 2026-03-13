import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../services/card_style_settings_service.dart';

class CardStyleSettingsPage extends StatefulWidget {
  const CardStyleSettingsPage({super.key});

  @override
  State<CardStyleSettingsPage> createState() => _CardStyleSettingsPageState();
}

class _CardStyleSettingsPageState extends State<CardStyleSettingsPage> {
  Color _cardColor = CardStyleSettingsService.defaultCardColor;
  double _opacity = CardStyleSettingsService.defaultOpacity;
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final settings = await CardStyleSettingsService.getAllSettings();
    
    setState(() {
      _cardColor = Color(settings['color'] as int);
      _opacity = settings['opacity'] as double;
      _isEnabled = settings['enabled'] as bool;
      _isLoading = false;
    });
  }

  Future<void> _updateCardColor(Color color) async {
    setState(() => _cardColor = color);
    await CardStyleSettingsService.saveCardColor(color);
  }

  Future<void> _updateOpacity(double value) async {
    setState(() => _opacity = value);
    await CardStyleSettingsService.saveCardOpacity(value);
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isEnabled = value);
    await CardStyleSettingsService.saveCardStyleEnabled(value);
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('重置样式'),
        content: const Text('确定要重置为默认卡片样式吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await CardStyleSettingsService.resetToDefaults();
      setState(() {
        _cardColor = CardStyleSettingsService.defaultCardColor;
        _opacity = CardStyleSettingsService.defaultOpacity;
        _isEnabled = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已重置为默认样式'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读卡片样式', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '重置为默认',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 实时预览卡片
                _buildPreviewCard(),
                
                const SizedBox(height: 24),
                
                // 启用开关
                _buildSwitchCard(
                  title: '启用自定义卡片样式',
                  subtitle: '使用您自定义的颜色和透明度',
                  value: _isEnabled,
                  onChanged: _toggleEnabled,
                ),
                
                const SizedBox(height: 16),
                
                // 颜色选择器
                _buildColorPickerCard(),
                
                const SizedBox(height: 16),
                
                // 不透明度滑块
                _buildSliderCard(
                  title: '卡片不透明度',
                  subtitle: '调整卡片的不透明效果（0-100%，越高越不透明）',
                  value: _opacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  onChanged: _updateOpacity,
                  displayValue: '${CardStyleSettingsService.opacityToPercentage(_opacity).round()}%',
                ),
                
                const SizedBox(height: 24),
                
                // 提示信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('温馨提示', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• 卡片样式设置会自动应用到所有日记卡片\n'
                        '• 建议不透明度保持在 70% 以上以确保文字可读性\n'
                        '• 您可以随时重置为默认样式\n'
                        '• 设置会在应用重启后保持',
                        style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility, size: 20, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  '实时预览',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // 预览卡片内容
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor.withOpacity(_opacity),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '3 月 15 日',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '日记',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '今天是个特别的日子，阳光明媚，心情愉悦。在公园里散步时，看到了许多美丽的花朵...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '#生活感悟',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 颜色信息
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                const Text('当前颜色：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${_cardColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  '不透明度：${CardStyleSettingsService.opacityToPercentage(_opacity).round()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.color_lens, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('卡片背景颜色', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('选择卡片的背景颜色', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 预设颜色
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildColorOption(Colors.white, '白色'),
                _buildColorOption(const Color(0xFFFDFBF7), '米白'),
                _buildColorOption(const Color(0xFFF5F5F5), '浅灰'),
                _buildColorOption(const Color(0xFFFFF9E6), '米黄'),
                _buildColorOption(const Color(0xFFE8F5E9), '浅绿'),
                _buildColorOption(const Color(0xFFE3F2FD), '浅蓝'),
                _buildColorOption(const Color(0xFFFCE4EC), '浅粉'),
                _buildColorOption(const Color(0xFFF3E5F5), '浅紫'),
              ],
            ),
            const SizedBox(height: 12),
            // 自定义颜色选择器
            Row(
              children: [
                const Text('自定义：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showCustomColorPicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: _cardColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, String name) {
    final isSelected = _cardColor.toARGB32() == color.toARGB32();
    
    return GestureDetector(
      onTap: () => _updateCardColor(color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.grey : Colors.grey.withOpacity(0.3),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.grey) : null,
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _showCustomColorPicker() async {
    final Color? pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) {
        Color tempColor = _cardColor;
        return AlertDialog(
          backgroundColor: const Color(0xFFFDFBF7),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('选择自定义颜色'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 颜色预览
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: tempColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                  // 颜色滑块
                  Column(
                    children: [
                      // 红色
                      Row(
                        children: [
                          const Text('R', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: tempColor.red.toDouble(),
                              min: 0,
                              max: 255,
                              divisions: 255,
                              activeColor: Colors.red,
                              onChanged: (value) {
                                setDialogState(() {
                                  tempColor = Color.fromRGBO(
                                    value.toInt(),
                                    tempColor.green,
                                    tempColor.blue,
                                    tempColor.alpha / 255.0,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      // 绿色
                      Row(
                        children: [
                          const Text('G', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: tempColor.green.toDouble(),
                              min: 0,
                              max: 255,
                              divisions: 255,
                              activeColor: Colors.green,
                              onChanged: (value) {
                                setDialogState(() {
                                  tempColor = Color.fromRGBO(
                                    tempColor.red,
                                    value.toInt(),
                                    tempColor.blue,
                                    tempColor.alpha / 255.0,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      // 蓝色
                      Row(
                        children: [
                          const Text('B', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: tempColor.blue.toDouble(),
                              min: 0,
                              max: 255,
                              divisions: 255,
                              activeColor: Colors.blue,
                              onChanged: (value) {
                                setDialogState(() {
                                  tempColor = Color.fromRGBO(
                                    tempColor.red,
                                    tempColor.green,
                                    value.toInt(),
                                    tempColor.alpha / 255.0,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempColor),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (pickedColor != null && mounted) {
      await _updateCardColor(pickedColor);
    }
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.toggle_on, color: Colors.green),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.opacity, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: Theme.of(context).primaryColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
