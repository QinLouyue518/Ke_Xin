import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

/// 日记导出结果
class DiaryExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  
  DiaryExportResult({
    required this.success,
    this.filePath,
    this.error,
  });
}

/// 日记导出服务
class DiaryExportService {
  /// 导出所有日记为 Markdown 文件并分享
  static Future<DiaryExportResult> exportAndShareDiaries() async {
    try {
      // 1. 从 SharedPreferences 读取所有日记数据
      final prefs = await SharedPreferences.getInstance();
      final String? diaryJson = prefs.getString('diary_data');
      
      if (diaryJson == null || diaryJson.isEmpty) {
        return DiaryExportResult(success: false, error: '暂无日记数据');
      }
      
      List<dynamic> allDiaries = jsonDecode(diaryJson);
      
      if (allDiaries.isEmpty) {
        return DiaryExportResult(success: false, error: '暂无日记数据');
      }
      
      // 2. 按日期排序（从新到旧）
      allDiaries.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      
      // 3. 生成 Markdown 内容
      final markdownContent = _generateMarkdown(allDiaries);
      
      // 4. 创建临时文件
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'kexin_export_$timestamp.md';
      final file = File('${directory.path}/$fileName');
      
      // 5. 写入文件（使用 UTF-8 编码，包含 BOM 以兼容 Windows）
      await file.writeAsBytes(
        [0xEF, 0xBB, 0xBF, ...utf8.encode(markdownContent)],
      );
      
      // 6. 分享文件
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端：调用系统分享
        await Share.shareXFiles([XFile(file.path)], subject: '刻心日记导出');
      } else {
        // 桌面端：打开文件所在文件夹
        await openFileLocation(file.path);
      }
      
      // 7. 返回文件路径
      return DiaryExportResult(
        success: true,
        filePath: file.path,
      );
    } catch (e) {
      return DiaryExportResult(success: false, error: '导出失败：$e');
    }
  }
  
  /// 在文件管理器中打开文件所在文件夹
  static Future<void> openFileLocation(String filePath) async {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [filePath]);
    }
  }
  
  /// 生成 Markdown 格式内容
  static String _generateMarkdown(List<dynamic> allDiaries) {
    final buffer = StringBuffer();
    
    // 添加文件头
    buffer.writeln('# 刻心日记');
    buffer.writeln();
    buffer.writeln('**导出时间**: ${DateFormat('yyyy 年 MM 月 dd 日 HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('**日记总数**: ${allDiaries.length} 篇');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    
    // 遍历每篇日记
    for (int i = 0; i < allDiaries.length; i++) {
      final diary = allDiaries[i];
      _appendDiaryToBuffer(buffer, diary, i, allDiaries);
    }
    
    // 添加文件尾
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('*本文件由刻心 App 自动生成*');
    buffer.writeln();
    buffer.writeln('> 刻心 - 记录你的心灵轨迹');
    
    return buffer.toString();
  }
  
  /// 将单篇日记添加到缓冲区
  static void _appendDiaryToBuffer(StringBuffer buffer, dynamic diary, int index, List<dynamic> allDiaries) {
    final date = diary['date'] ?? '';
    final content = diary['content'] ?? '';
    final mood = diary['mood'] ?? '';
    
    // 标题：日期 - 情绪关键词
    buffer.writeln();
    buffer.writeln('## $date - $mood');
    buffer.writeln();
    
    // 日记正文
    buffer.writeln(content);
    buffer.writeln();
    
    // 添加分割线（最后一篇日记不需要）
    if (index < allDiaries.length - 1) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
  }
  
  /// 获取日记统计信息
  static Future<Map<String, dynamic>> getExportStats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? diaryJson = prefs.getString('diary_data');
    
    if (diaryJson == null || diaryJson.isEmpty) {
      return {
        'count': 0,
        'firstDate': null,
        'lastDate': null,
      };
    }
    
    List<dynamic> allDiaries = jsonDecode(diaryJson);
    
    if (allDiaries.isEmpty) {
      return {
        'count': 0,
        'firstDate': null,
        'lastDate': null,
      };
    }
    
    // 按日期排序
    allDiaries.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    
    return {
      'count': allDiaries.length,
      'firstDate': allDiaries.first['date'],
      'lastDate': allDiaries.last['date'],
      'estimatedSize': _estimateFileSize(allDiaries),
    };
  }
  
  /// 估算导出文件大小（字节）
  static int _estimateFileSize(List<dynamic> allDiaries) {
    int totalSize = 0;
    
    for (var diary in allDiaries) {
      // 标题
      totalSize += 50;
      // 元数据
      totalSize += 200;
      // 内容
      totalSize += diary['content']?.toString().length ?? 0;
      // 分隔符
      totalSize += 100;
    }
    
    return totalSize;
  }
}
