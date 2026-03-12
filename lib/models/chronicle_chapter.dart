// ChronicleChapter 类表示流年史官生成的自传章节
class ChronicleChapter {
  final String id;
  final String title;
  final String content;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final String summary; // 用于连载的摘要
  final int order; // 章节序号
  final bool isFinalized; // 是否定稿（定稿后不可再从AI重写，但可手动修）

  ChronicleChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.summary = '',
    this.order = 1,
    this.isFinalized = false,
  });

  factory ChronicleChapter.fromJson(Map<String, dynamic> json) {
    return ChronicleChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      createdAt: DateTime.parse(json['created_at']),
      summary: json['summary'] as String? ?? '',
      order: json['order'] as int? ?? 1,
      isFinalized: json['is_finalized'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'summary': summary,
      'order': order,
      'is_finalized': isFinalized,
    };
  }

  ChronicleChapter copyWith({
    String? title,
    String? content,
    String? summary,
    bool? isFinalized,
  }) {
    return ChronicleChapter(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      summary: summary ?? this.summary,
      order: order,
      isFinalized: isFinalized ?? this.isFinalized,
    );
  }
}

