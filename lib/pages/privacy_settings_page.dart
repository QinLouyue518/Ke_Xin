import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/diary_export_service.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  
  @override
  void initState() {
    super.initState();
  }

  Future<void> _exportDiaries() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("正在生成导出文件..."),
            SizedBox(height: 8),
            Text("请稍候", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    final result = await DiaryExportService.exportDiaries();
    
    // 关闭加载对话框
    if (context.mounted) {
      Navigator.pop(context);
    }
    
    if (result.success && result.filePath != null) {
      // 显示成功对话框，包含文件路径和操作按钮
      if (context.mounted) {
        _showExportSuccessDialog(context, result.filePath!);
      }
    } else {
      // 显示错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? '导出失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text("导出成功"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("文件已保存到：", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 12, fontFamily: 'Consolas', height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "💡 提示：\n• 点击\"打开文件夹\"可在文件管理器中查看\n• 点击\"复制路径\"可复制文件路径\n• 文件为 Markdown 格式，可用文本编辑器打开",
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              // 复制路径到剪贴板
              Clipboard.setData(ClipboardData(text: filePath));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("路径已复制到剪贴板"),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text("复制路径"),
          ),
          TextButton.icon(
            onPressed: () async {
              await DiaryExportService.openFileLocation(filePath);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text("打开文件夹"),
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    // 清除 AI 报告缓存等非核心数据
    final keys = prefs.getKeys();
    int count = 0;
    for (String key in keys) {
      if (key.startsWith('report_cache_')) {
        await prefs.remove(key);
        count++;
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已清理 $count 条缓存数据")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("隐私与数据", style: TextStyle(fontWeight: FontWeight.bold)),
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
          const Text("数据管理", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.file_download, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  title: const Text("导出日记数据", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("导出所有日记为 Markdown 文件", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: _exportDiaries,
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.cleaning_services_outlined, color: Colors.orange, size: 20),
                  ),
                  title: const Text("清除缓存", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("清理 AI 报告缓存等临时文件", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: _clearCache,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "注意：目前数据仅保存在您的本地设备上。建议定期导出备份。",
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
