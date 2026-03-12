import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'life_stage.dart';

class TimeService {
  // 私有构造函数，防止实例化
  TimeService._();

  static const String _lifeStagesKey = 'life_stages_data';

  /// 从 SharedPreferences 加载 LifeStage 列表
  static Future<List<LifeStage>> loadLifeStages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lifeStagesJson = prefs.getString(_lifeStagesKey);

    try {
      if (lifeStagesJson == null || lifeStagesJson.isEmpty) {
        return [];
      }
      final List<dynamic> jsonList = json.decode(lifeStagesJson);
      return jsonList.map((json) => LifeStage.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error decoding life stages: $e");
      return [];
    }
  }

  /// 将 LifeStage 列表保存到 SharedPreferences
  static Future<void> saveLifeStages(List<LifeStage> stages) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = stages.map((stage) => stage.toJson()).toList();
    final String lifeStagesJson = json.encode(jsonList);
    await prefs.setString(_lifeStagesKey, lifeStagesJson);
  }

  /// 根据日期查找对应的 LifeStage 名称
  static Future<String?> findLifeStageNameForDate(DateTime date) async {
    final List<LifeStage> lifeStages = await loadLifeStages();
    
    for (var stage in lifeStages) {
      if (!date.isBefore(stage.startDate) && !date.isAfter(stage.endDate)) {
        return stage.name;
      }
    }
    return null;
  }
}
