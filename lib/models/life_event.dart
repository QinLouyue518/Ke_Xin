class LifeEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // "ongoing" or "completed"
  final List<String> diaryIds;
  final String? summary;

  LifeEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    this.status = "ongoing",
    this.diaryIds = const [],
    this.summary,
  });

  factory LifeEvent.fromJson(Map<String, dynamic> json) {
    return LifeEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      status: json['status'],
      diaryIds: List<String>.from(json['diaryIds'] ?? []),
      summary: json['summary'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'diaryIds': diaryIds,
      'summary': summary,
    };
  }

  LifeEvent copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    List<String>? diaryIds,
    String? summary,
  }) {
    return LifeEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      diaryIds: diaryIds ?? this.diaryIds,
      summary: summary ?? this.summary,
    );
  }
}

