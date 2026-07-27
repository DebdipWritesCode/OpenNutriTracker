class AiExtractedExercise {
  final String originalText;
  final String canonicalName;
  final int? sets;
  final int? repsPerSet;
  final double? loadValue;
  final String? loadUnit;
  final double confidence;
  final bool requiresUserConfirmation;

  const AiExtractedExercise({
    required this.originalText,
    required this.canonicalName,
    required this.sets,
    required this.repsPerSet,
    required this.loadValue,
    required this.loadUnit,
    required this.confidence,
    required this.requiresUserConfirmation,
  });

  factory AiExtractedExercise.fromJson(Map<String, dynamic> json) =>
      AiExtractedExercise(
        originalText: json['original_text'] as String,
        canonicalName: json['canonical_name'] as String,
        sets: (json['sets'] as num?)?.toInt(),
        repsPerSet: (json['reps_per_set'] as num?)?.toInt(),
        loadValue: (json['load_value'] as num?)?.toDouble(),
        loadUnit: json['load_unit'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        requiresUserConfirmation:
            json['requires_user_confirmation'] as bool? ?? false,
      );

  AiExtractedExercise copyWith({
    String? canonicalName,
    int? sets,
    bool clearSets = false,
    int? repsPerSet,
    bool clearReps = false,
    double? loadValue,
    String? loadUnit,
    bool clearLoadValue = false,
    bool clearLoad = false,
    bool? requiresUserConfirmation,
  }) => AiExtractedExercise(
    originalText: originalText,
    canonicalName: canonicalName ?? this.canonicalName,
    sets: clearSets ? null : (sets ?? this.sets),
    repsPerSet: clearReps ? null : (repsPerSet ?? this.repsPerSet),
    loadValue: clearLoad || clearLoadValue
        ? null
        : (loadValue ?? this.loadValue),
    loadUnit: clearLoad ? null : (loadUnit ?? this.loadUnit),
    confidence: confidence,
    requiresUserConfirmation:
        requiresUserConfirmation ?? this.requiresUserConfirmation,
  );
}

class AiActivityAnalysis {
  final List<AiExtractedExercise> exercises;
  final double? statedDurationMinutes;
  final List<String> notes;
  final String modelUsed;

  const AiActivityAnalysis({
    required this.exercises,
    required this.statedDurationMinutes,
    required this.notes,
    required this.modelUsed,
  });

  factory AiActivityAnalysis.fromJson(Map<String, dynamic> json) =>
      AiActivityAnalysis(
        exercises: (json['exercises'] as List<dynamic>)
            .map(
              (item) =>
                  AiExtractedExercise.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        statedDurationMinutes: (json['stated_duration_minutes'] as num?)
            ?.toDouble(),
        notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>(),
        modelUsed: json['model_used'] as String,
      );
}
