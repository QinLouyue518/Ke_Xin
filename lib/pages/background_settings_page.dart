import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/background_settings_service.dart';

class BackgroundSettingsPage extends StatefulWidget {
  const BackgroundSettingsPage({super.key});

  @override
  State<BackgroundSettingsPage> createState() => _BackgroundSettingsPageState();
}

class _BackgroundSettingsPageState extends State<BackgroundSettingsPage> {
  File? _backgroundImage;
  double _blurAmount = 5.0;
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final settings = await BackgroundSettingsService.getAllSettings();
    final path = settings['path'] as String?;
    
    setState(() {
      _blurAmount = settings['blur'] as double;
      _isEnabled = settings['enabled'] as bool;
      _backgroundImage = path != null ? File(path) : null;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final path = await BackgroundSettingsService.pickAndCropImage();
    
    if (path != null && mounted) {
      setState(() {
        _backgroundImage = File(path);
        _isEnabled = true;
      });
      await BackgroundSettingsService.saveBackgroundPath(path);
      await BackgroundSettingsService.saveBackgroundEnabled(true);
      
      if (mounted) {
        // 显示成功提示，但留在当前页面方便继续调整虚化
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('背景图片设置成功，您可以继续调整虚化程度'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateBlur(double value) async {
    setState(() => _blurAmount = value);
    await BackgroundSettingsService.saveBackgroundBlur(value);
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isEnabled = value);
    await BackgroundSettingsService.saveBackgroundEnabled(value);
  }

  Future<void> _removeBackground() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除背景'),
        content: const Text('确定要删除自定义背景吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await BackgroundSettingsService.removeBackground();
      setState(() {
        _backgroundImage = null;
        _isEnabled = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('背景已删除'),
            backgroundColor: Colors.orange,
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
        title: const Text('背景设置', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 预览卡片
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_backgroundImage != null && _isEnabled)
                          Image.file(
                            _backgroundImage!,
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_outlined, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('暂无背景图片', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        // 虚化效果预览层
                        if (_backgroundImage != null && _isEnabled && _blurAmount > 0)
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: _blurAmount, sigmaY: _blurAmount),
                            child: Container(color: Colors.transparent),
                          ),
                        // 启用状态遮罩
                        if (!_isEnabled)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: Text(
                                '已禁用',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 启用开关
                _buildSwitchCard(
                  title: '启用自定义背景',
                  subtitle: '显示您设置的背景图片',
                  value: _isEnabled,
                  onChanged: _toggleEnabled,
                ),
                
                const SizedBox(height: 16),
                
                // 虚化调节
                _buildSliderCard(
                  title: '背景虚化程度',
                  subtitle: '调整背景模糊效果（0-10）',
                  value: _blurAmount,
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  onChanged: _updateBlur,
                ),
                
                const SizedBox(height: 16),
                
                // 选择背景
                Container(
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
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
                    ),
                    title: const Text('选择背景图片', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('从相册选择并裁切图片', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: _isEnabled ? _pickImage : null,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 删除背景
                if (_backgroundImage != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      title: const Text('删除背景', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                      subtitle: const Text('移除自定义背景图片', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: _removeBackground,
                    ),
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
                        '• 背景图片仅保存在本地设备\n'
                        '• 建议使用清晰的风景或纹理图片\n'
                        '• 虚化效果可以提升文字可读性\n'
                        '• 随时可以删除或更换背景',
                        style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
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
                  child: const Icon(Icons.blur_on, color: Colors.orange),
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
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: Colors.orange,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
