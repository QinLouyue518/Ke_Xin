// LifeStage 类表示人生的一个阶段。
class LifeStage {
  /// 唯一标识
  final String id;

  /// 阶段名称，例如“高中”
  final String name;

  /// 阶段开始时间
  final DateTime startDate;

  /// 阶段结束时间
  final DateTime endDate;

  /// 关键词标签
  final List<String> tags;

  /// 构造函数，所有字段必需
  LifeStage({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.tags,
  });

  /// 从 JSON 构建 LifeStage 实例
  /// 注意要将字符串解析为 DateTime
  factory LifeStage.fromJson(Map<String, dynamic> json) {
    return LifeStage(
      id: json['id'] as String,
      name: json['name'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      tags: List<String>.from(json['tags'] as List),
    );
  }

  /// 转换实例为 JSON，DateTime 需格式化为字符串
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'tags': tags,
    };
  }
}
