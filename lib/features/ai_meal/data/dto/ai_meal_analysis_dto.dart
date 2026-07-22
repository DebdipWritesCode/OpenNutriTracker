import 'package:equatable/equatable.dart';

class AiExtractedFood extends Equatable {
  final String originalText;
  final String canonicalName;
  final double? quantity;
  final String? unit;
  final double? estimatedGrams;
  final String? preparation;
  final double confidence;
  final bool requiresUserConfirmation;

  const AiExtractedFood({
    required this.originalText,
    required this.canonicalName,
    required this.quantity,
    required this.unit,
    required this.estimatedGrams,
    required this.preparation,
    required this.confidence,
    required this.requiresUserConfirmation,
  });

  factory AiExtractedFood.fromJson(Map<String, dynamic> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    return AiExtractedFood(
      originalText: json['original_text'] as String,
      canonicalName: json['canonical_name'] as String,
      quantity: number('quantity'),
      unit: json['unit'] as String?,
      estimatedGrams: number('estimated_grams'),
      preparation: json['preparation'] as String?,
      confidence: number('confidence') ?? 0,
      requiresUserConfirmation:
          json['requires_user_confirmation'] as bool? ?? false,
    );
  }

  AiExtractedFood copyWith({String? canonicalName}) => AiExtractedFood(
    originalText: originalText,
    canonicalName: canonicalName ?? this.canonicalName,
    quantity: quantity,
    unit: unit,
    estimatedGrams: estimatedGrams,
    preparation: preparation,
    confidence: confidence,
    requiresUserConfirmation: requiresUserConfirmation,
  );

  @override
  List<Object?> get props => [
    originalText,
    canonicalName,
    quantity,
    unit,
    estimatedGrams,
    preparation,
    confidence,
    requiresUserConfirmation,
  ];
}

class AiMealAnalysis extends Equatable {
  final List<AiExtractedFood> foods;
  final List<String> notes;
  final String modelUsed;

  const AiMealAnalysis({
    required this.foods,
    required this.notes,
    required this.modelUsed,
  });

  factory AiMealAnalysis.fromJson(Map<String, dynamic> json) => AiMealAnalysis(
    foods: (json['foods'] as List<dynamic>? ?? const [])
        .map((item) => AiExtractedFood.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    notes: (json['notes'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    modelUsed: json['model_used'] as String? ?? 'unknown',
  );

  @override
  List<Object?> get props => [foods, notes, modelUsed];
}
