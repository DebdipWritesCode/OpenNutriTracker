import 'package:equatable/equatable.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';

class AiMealDraftItem extends Equatable {
  final AiExtractedFood extractedFood;
  final String searchQuery;
  final List<MealEntity> candidates;
  final int selectedCandidateIndex;
  final double? amount;
  final bool isResolving;

  const AiMealDraftItem({
    required this.extractedFood,
    required this.searchQuery,
    required this.candidates,
    required this.selectedCandidateIndex,
    required this.amount,
    this.isResolving = false,
  });

  MealEntity? get selectedMeal =>
      selectedCandidateIndex >= 0 && selectedCandidateIndex < candidates.length
      ? candidates[selectedCandidateIndex]
      : null;

  String get amountUnit => selectedMeal?.isLiquid == true ? 'ml' : 'g';

  bool get isReady =>
      selectedMeal != null && amount != null && amount! > 0 && amount! <= 10000;

  bool get needsAttention => !isReady || extractedFood.requiresUserConfirmation;

  double get calories => amount == null
      ? 0
      : amount! * (selectedMeal?.nutriments.energyPerUnit ?? 0);

  double get carbohydrates => amount == null
      ? 0
      : amount! * (selectedMeal?.nutriments.carbohydratesPerUnit ?? 0);

  double get fat =>
      amount == null ? 0 : amount! * (selectedMeal?.nutriments.fatPerUnit ?? 0);

  double get protein => amount == null
      ? 0
      : amount! * (selectedMeal?.nutriments.proteinsPerUnit ?? 0);

  AiMealDraftItem copyWith({
    AiExtractedFood? extractedFood,
    String? searchQuery,
    List<MealEntity>? candidates,
    int? selectedCandidateIndex,
    double? amount,
    bool clearAmount = false,
    bool? isResolving,
  }) => AiMealDraftItem(
    extractedFood: extractedFood ?? this.extractedFood,
    searchQuery: searchQuery ?? this.searchQuery,
    candidates: candidates ?? this.candidates,
    selectedCandidateIndex:
        selectedCandidateIndex ?? this.selectedCandidateIndex,
    amount: clearAmount ? null : (amount ?? this.amount),
    isResolving: isResolving ?? this.isResolving,
  );

  @override
  List<Object?> get props => [
    extractedFood,
    searchQuery,
    candidates,
    selectedCandidateIndex,
    amount,
    isResolving,
  ];
}
