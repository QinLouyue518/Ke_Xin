// LiteraryFingerprint 类表示用户的写作风格指纹
// 包含定量和定性的风格描述，用于指导 AI 生成传记
class LiteraryFingerprint {
  // 核心定位
  final String coreIdentity; // 例如：以细腻自省与青春记忆为引擎...
  
  // 创作方向
  final List<String> primaryDirections; // 主方向
  final List<String> secondaryDirections; // 次方向

  // 风格画像 (定量数据)
  final String pronounTendency; // 代词倾向 (我们/你/他 使用比)
  final String sentenceRhythm; // 句速与节奏 (逗号/句号比)
  final String rhetoricDensity; // 修辞密度 (隐喻/术语/设问)
  final String interactionFrequency; // 互动频率
  final String structuralFeatures; // 功能词与结构 (句末语气词等)

  // 风格要点 (定性描述)
  final String rhythmDescription; // 节奏与句型描述
  final String rhetoricDescription; // 修辞与具体化描述
  final String narrativeLogic; // 篇章推进逻辑
  final String toneDescription; // 互动与口吻

  // ✨ Phase 2 新增：深层心理与文学特征
  final String narrativeMode; // 叙事模式 (如：沉浸式体验、抽离式观察、混合视角)
  final String emotionalTone; // 情绪基调 (如：虚无主义、热烈、克制、焦虑、温暖)
  final String metaCognition; // 元认知/思维跳跃度 (如：高频联想、线性叙事、哲学升华)
  final String vocabularyPreference; // 词汇偏好 (如：喜欢用"深海/光/雨"等意象，或偏好学术词汇)

  LiteraryFingerprint({
    required this.coreIdentity,
    required this.primaryDirections,
    required this.secondaryDirections,
    required this.pronounTendency,
    required this.sentenceRhythm,
    required this.rhetoricDensity,
    required this.interactionFrequency,
    required this.structuralFeatures,
    required this.rhythmDescription,
    required this.rhetoricDescription,
    required this.narrativeLogic,
    required this.toneDescription,
    this.narrativeMode = '',
    this.emotionalTone = '',
    this.metaCognition = '',
    this.vocabularyPreference = '',
  });

  factory LiteraryFingerprint.fromJson(Map<String, dynamic> json) {
    return LiteraryFingerprint(
      coreIdentity: json['core_identity'] as String? ?? '',
      primaryDirections: List<String>.from(json['primary_directions'] as List? ?? []),
      secondaryDirections: List<String>.from(json['secondary_directions'] as List? ?? []),
      pronounTendency: json['pronoun_tendency'] as String? ?? '',
      sentenceRhythm: json['sentence_rhythm'] as String? ?? '',
      rhetoricDensity: json['rhetoric_density'] as String? ?? '',
      interactionFrequency: json['interaction_frequency'] as String? ?? '',
      structuralFeatures: json['structural_features'] as String? ?? '',
      rhythmDescription: json['rhythm_description'] as String? ?? '',
      rhetoricDescription: json['rhetoric_description'] as String? ?? '',
      narrativeLogic: json['narrative_logic'] as String? ?? '',
      toneDescription: json['tone_description'] as String? ?? '',
      // Phase 2 新字段
      narrativeMode: json['narrative_mode'] as String? ?? '',
      emotionalTone: json['emotional_tone'] as String? ?? '',
      metaCognition: json['meta_cognition'] as String? ?? '',
      vocabularyPreference: json['vocabulary_preference'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'core_identity': coreIdentity,
      'primary_directions': primaryDirections,
      'secondary_directions': secondaryDirections,
      'pronoun_tendency': pronounTendency,
      'sentence_rhythm': sentenceRhythm,
      'rhetoric_density': rhetoricDensity,
      'interaction_frequency': interactionFrequency,
      'structural_features': structuralFeatures,
      'rhythm_description': rhythmDescription,
      'rhetoric_description': rhetoricDescription,
      'narrative_logic': narrativeLogic,
      'tone_description': toneDescription,
      // Phase 2 新字段
      'narrative_mode': narrativeMode,
      'emotional_tone': emotionalTone,
      'meta_cognition': metaCognition,
      'vocabulary_preference': vocabularyPreference,
    };
  }

  factory LiteraryFingerprint.empty() {
    return LiteraryFingerprint(
      coreIdentity: '',
      primaryDirections: [],
      secondaryDirections: [],
      pronounTendency: '',
      sentenceRhythm: '',
      rhetoricDensity: '',
      interactionFrequency: '',
      structuralFeatures: '',
      rhythmDescription: '',
      rhetoricDescription: '',
      narrativeLogic: '',
      toneDescription: '',
      narrativeMode: '',
      emotionalTone: '',
      metaCognition: '',
      vocabularyPreference: '',
    );
  }
  
  bool get isEmpty => coreIdentity.isEmpty;

  // 生成 Prompt 描述
  String toPromptString() {
    final buffer = StringBuffer();
    buffer.writeln("- 核心基调：$coreIdentity");
    buffer.writeln("- 句法节奏：$sentenceRhythm；$rhythmDescription");
    buffer.writeln("- 代词习惯：$pronounTendency；$toneDescription");
    buffer.writeln("- 修辞特征：$rhetoricDensity；$rhetoricDescription");
    buffer.writeln("- 语气结构：$structuralFeatures");
    
    // Phase 2 增强描述
    if (narrativeMode.isNotEmpty) buffer.writeln("- 叙事视角：$narrativeMode");
    if (emotionalTone.isNotEmpty) buffer.writeln("- 情绪底色：$emotionalTone");
    if (metaCognition.isNotEmpty) buffer.writeln("- 思维模式：$metaCognition");
    if (vocabularyPreference.isNotEmpty) buffer.writeln("- 词汇偏好：$vocabularyPreference");
    
    return buffer.toString();
  }
}
