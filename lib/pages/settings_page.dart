import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'ai_settings_page.dart';
import 'privacy_settings_page.dart';
import 'api_config_page.dart';
import 'background_settings_page.dart';
import 'card_style_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("设置", style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text("通用", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _buildPrivacyCard(context),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text("AI 伴侣", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _buildAICard(context),
          _buildApiConfigCard(context),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text("外观个性化", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _buildCardStyleCard(context),
          _buildBackgroundCard(context),
          _buildThemeCard(context),
        ],
      ),
    );
  }

  Widget _buildBackgroundCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withOpacity(0.1),
          child: const Icon(Icons.palette, color: Colors.purple),
        ),
        title: const Text("背景设置", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("自定义背景图片、虚化效果", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BackgroundSettingsPage()),
          );
          // 返回时刷新设置页面
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildPrivacyCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.withOpacity(0.1),
          child: const Icon(Icons.security, color: Colors.blueGrey),
        ),
        title: const Text("隐私与数据", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("应用锁 · 数据导出备份", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacySettingsPage()));
        },
      ),
    );
  }

  Widget _buildAICard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(Icons.psychology, color: Theme.of(context).primaryColor),
        ),
        title: const Text("清言客设置", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("自定义 AI 的称呼与回复风格", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AISettingsPage()));
        },
      ),
    );
  }

  Widget _buildApiConfigCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: const Icon(Icons.api, color: Colors.orange),
        ),
        title: const Text("AI 模型配置", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("自定义 API Key、URL 和模型", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ApiConfigPage()));
        },
      ),
    );
  }

  Widget _buildCardStyleCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.pink.withOpacity(0.1),
          child: const Icon(Icons.credit_card, color: Colors.pink),
        ),
        title: const Text("阅读卡片样式", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("自定义卡片颜色、不透明度", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CardStyleSettingsPage()),
          );
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("主题色调", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppTheme.themeColors.entries.map((entry) {
                return _buildColorOption(context, entry.key, entry.value);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, String name, Color color) {
    final currentTheme = Provider.of<ThemeProvider>(context).themeColor;
    final isSelected = currentTheme.toARGB32() == color.toARGB32();

    return GestureDetector(
      onTap: () {
        Provider.of<ThemeProvider>(context, listen: false).setThemeColor(color);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.grey, width: 3) : null,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
              ],
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black87 : Colors.grey)),
        ],
      ),
    );
  }
}

