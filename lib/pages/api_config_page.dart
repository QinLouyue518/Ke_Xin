import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_settings_service.dart';

class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('custom_api_key') ?? '';
    final apiUrl = prefs.getString('custom_api_url') ?? ApiSettingsService.defaultApiUrl;
    final modelName = prefs.getString('custom_model_name') ?? ApiSettingsService.defaultModelName;
    
    // 只在初始化时设置控制器文本，避免在 setState 中更新导致焦点丢失
    _apiKeyController.text = apiKey;
    _apiUrlController.text = apiUrl;
    _modelNameController.text = modelName;
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final apiKey = _apiKeyController.text.trim();
    final apiUrl = _apiUrlController.text.trim();
    final modelName = _modelNameController.text.trim();

    if (apiKey.isEmpty) {
      _showErrorDialog('API Key 不能为空');
      return;
    }

    if (apiUrl.isEmpty) {
      _showErrorDialog('API URL 不能为空');
      return;
    }

    if (modelName.isEmpty) {
      _showErrorDialog('模型名称不能为空');
      return;
    }

    await ApiSettingsService.saveSettings(
      apiKey: apiKey,
      apiUrl: apiUrl,
      modelName: modelName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 配置已保存'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置配置'),
        content: const Text('确定要重置为默认配置吗？\n这将清空所有自定义设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiSettingsService.resetToDefaults();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已重置为默认配置')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    final apiUrl = _apiUrlController.text.trim();
    final modelName = _modelNameController.text.trim();

    if (apiKey.isEmpty) {
      _showErrorDialog('请先填写 API Key');
      return;
    }

    if (apiUrl.isEmpty) {
      _showErrorDialog('请先填写 API URL');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // 发送测试请求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName.isEmpty ? ApiSettingsService.defaultModelName : modelName,
          'messages': [
            {'role': 'user', 'content': 'hi'},
          ],
          'max_tokens': 10,
        }),
      ).timeout(const Duration(seconds: 30));

      setState(() {
        _isTesting = false;
        if (response.statusCode == 200) {
          _testSuccess = true;
          _testResult = '✅ 连接成功！API 配置有效。';
        } else {
          _testSuccess = false;
          _testResult = '❌ 连接失败 (状态码：${response.statusCode})\n${response.body}';
        }
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = '❌ 连接失败：$e';
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 模型配置', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 说明卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text('配置说明', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '为了保护 API 余额并允许自定义，您可以配置自己的 API 密钥。\n\n'
                  '• API Key: 从 DeepSeek 或其他兼容平台获取\n'
                  '• API URL: API 接口地址\n'
                  '• 模型名称：使用的模型标识',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // API Key 输入框
          const Text('API Key *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '请输入你的 API Key (sk-xxxx)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.key, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          const Text('从 DeepSeek 官网或其他平台获取', style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          const SizedBox(height: 24),

          // API URL 输入框
          const Text('API URL *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _apiUrlController,
            decoration: InputDecoration(
              hintText: 'https://api.deepseek.com/chat/completions',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.link, color: Colors.grey),
            ),
          ),
          
          const SizedBox(height: 24),

          // 模型名称输入框
          const Text('模型名称', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _modelNameController,
            decoration: InputDecoration(
              hintText: 'deepseek-chat (留空使用默认值)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.smart_toy, color: Colors.grey),
            ),
          ),
          
          const SizedBox(height: 32),

          // 测试连接按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),

          // 测试结果显示
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _testSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _testSuccess ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 2,
              ),
              child: const Text('保存配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 16),

          // 重置按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _resetToDefaults,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('重置为默认', style: TextStyle(fontSize: 16)),
            ),
          ),

          const SizedBox(height: 32),

          // 安全提示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('安全提示', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 4),
                      const Text(
                        '您的 API Key 仅存储在本地，不会上传到服务器。\n请妥善保管，不要分享给他人。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
