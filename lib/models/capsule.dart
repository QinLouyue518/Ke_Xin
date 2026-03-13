class Capsule {
  final String id;
  final String content;
  final DateTime createdAt;
  final String? mood; // 可选的情绪标签
  final List<String> tags; // 可选的标签

  Capsule({
    required this.id,
    required this.content,
    required this.createdAt,
    this.mood,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'mood': mood,
      'tags': tags,
    };
  }

  factory Capsule.fromJson(Map<String, dynamic> json) {
    return Capsule(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mood: json['mood'] as String?,
      tags: json['tags'] != null 
          ? List<String>.from(json['tags']) 
          : [],
    );
  }
}
