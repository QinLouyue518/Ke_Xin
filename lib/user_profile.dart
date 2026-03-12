
// PersonalityTraits 类表示人格特质
class PersonalityTraits {
  final String summary;
  final List<String> tags;
  final List<String> evidenceIds;

  PersonalityTraits({
    required this.summary,
    required this.tags,
    required this.evidenceIds,
  });

  factory PersonalityTraits.fromJson(Map<String, dynamic> json) {
    return PersonalityTraits(
      summary: json['summary'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List? ?? []),
      evidenceIds: List<String>.from(json['evidence_ids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'tags': tags,
      'evidence_ids': evidenceIds,
    };
  }
}

// CoreValue 类表示用户核心价值观
class CoreValue {
  final String value;
  final String description;
  final List<String> evidenceIds;

  CoreValue({
    required this.value,
    required this.description,
    required this.evidenceIds,
  });

  factory CoreValue.fromJson(Map<String, dynamic> json) {
    return CoreValue(
      value: json['value'] as String? ?? '',
      description: json['description'] as String? ?? '',
      evidenceIds: List<String>.from(json['evidence_ids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'description': description,
      'evidence_ids': evidenceIds,
    };
  }
}

// ThinkingPattern 类表示用户思维模式
class ThinkingPattern {
  final String pattern;
  final String description;
  final List<String> evidenceIds;

  ThinkingPattern({
    required this.pattern,
    required this.description,
    required this.evidenceIds,
  });

  factory ThinkingPattern.fromJson(Map<String, dynamic> json) {
    return ThinkingPattern(
      pattern: json['pattern'] as String? ?? '',
      description: json['description'] as String? ?? '',
      evidenceIds: List<String>.from(json['evidence_ids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pattern': pattern,
      'description': description,
      'evidence_ids': evidenceIds,
    };
  }
}

// RecentState 类表示用户近期状态
class RecentState {
  final String summary;
  final List<String> keywords;
  final List<String> evidenceIds;

  RecentState({
    required this.summary,
    required this.keywords,
    required this.evidenceIds,
  });

  factory RecentState.fromJson(Map<String, dynamic> json) {
    return RecentState(
      summary: json['summary'] as String? ?? '',
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      evidenceIds: List<String>.from(json['evidence_ids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'keywords': keywords,
      'evidence_ids': evidenceIds,
    };
  }
}

// CommunicationPreference 类表示用户沟通偏好
class CommunicationPreference {
  final String summary;
  final String style;
  final List<String> evidenceIds;

  CommunicationPreference({
    required this.summary,
    required this.style,
    required this.evidenceIds,
  });

  factory CommunicationPreference.fromJson(Map<String, dynamic> json) {
    return CommunicationPreference(
      summary: json['summary'] as String? ?? '',
      style: json['style'] as String? ?? '',
      evidenceIds: List<String>.from(json['evidence_ids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'style': style,
      'evidence_ids': evidenceIds,
    };
  }
}

// UserProfile 类表示用户的完整画像数据模型 (五维人格)
class UserProfile {
  final PersonalityTraits personalityTraits;
  final List<CoreValue> coreValues;
  final List<ThinkingPattern> thinkingPatterns;
  final RecentState recentState;
  final CommunicationPreference communicationPreference;

  UserProfile({
    required this.personalityTraits,
    required this.coreValues,
    required this.thinkingPatterns,
    required this.recentState,
    required this.communicationPreference,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      personalityTraits: PersonalityTraits.fromJson(json['personality_traits'] as Map<String, dynamic>? ?? {}),
      coreValues: (json['core_values'] as List?)
          ?.map((e) => CoreValue.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      thinkingPatterns: (json['thinking_patterns'] as List?)
          ?.map((e) => ThinkingPattern.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      recentState: RecentState.fromJson(json['recent_state'] as Map<String, dynamic>? ?? {}),
      communicationPreference: CommunicationPreference.fromJson(json['communication_preference'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'personality_traits': personalityTraits.toJson(),
      'core_values': coreValues.map((e) => e.toJson()).toList(),
      'thinking_patterns': thinkingPatterns.map((e) => e.toJson()).toList(),
      'recent_state': recentState.toJson(),
      'communication_preference': communicationPreference.toJson(),
    };
  }

  factory UserProfile.empty() {
    return UserProfile(
      personalityTraits: PersonalityTraits(
        summary: '',
        tags: [],
        evidenceIds: [],
      ),
      coreValues: [],
      thinkingPatterns: [],
      recentState: RecentState(
        summary: '',
        keywords: [],
        evidenceIds: [],
      ),
      communicationPreference: CommunicationPreference(
        summary: '',
        style: '',
        evidenceIds: [],
      ),
    );
  }
}
