import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';

abstract interface class AiNutritionResolver {
  Future<AiMealDraftItem> resolve(AiExtractedFood food, {String? query});
}

class TrustedDatabaseNutritionResolver implements AiNutritionResolver {
  final SearchProductsUseCase _searchProducts;

  TrustedDatabaseNutritionResolver(this._searchProducts);

  @override
  Future<AiMealDraftItem> resolve(AiExtractedFood food, {String? query}) async {
    final normalizedQuery = (query ?? food.canonicalName).trim();
    final results = await Future.wait([
      _searchProducts.searchFDCFoodByString(normalizedQuery),
      _searchProducts.searchOFFProductsByString(normalizedQuery),
    ]);

    final candidates = _rankAndDeduplicate(normalizedQuery, [
      ...results[0].meals,
      ...results[1].meals,
    ]);

    return AiMealDraftItem(
      extractedFood: food.copyWith(canonicalName: normalizedQuery),
      searchQuery: normalizedQuery,
      candidates: candidates,
      selectedCandidateIndex: candidates.isEmpty ? -1 : 0,
      amount: _initialAmount(food),
    );
  }

  double? _initialAmount(AiExtractedFood food) {
    if (food.estimatedGrams != null) return food.estimatedGrams;
    final unit = food.unit?.trim().toLowerCase();
    if (unit == 'g' || unit == 'gram' || unit == 'grams' || unit == 'ml') {
      return food.quantity;
    }
    return null;
  }

  List<MealEntity> _rankAndDeduplicate(String query, List<MealEntity> meals) {
    final normalized = query.toLowerCase();
    final seen = <String>{};
    final eligible = meals.where((meal) {
      if (meal.name == null || meal.nutriments.energyKcal100 == null) {
        return false;
      }
      return seen.add('${meal.source.name}:${meal.code ?? meal.name}');
    }).toList();

    int score(MealEntity meal) {
      final name = meal.name!.toLowerCase();
      var value = meal.source == MealSourceEntity.fdc ? 12 : 0;
      if (name == normalized) value += 100;
      if (name.startsWith(normalized)) value += 60;
      if (name.contains(normalized)) value += 35;
      final words = normalized
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty);
      value += words.where(name.contains).length * 8;
      return value;
    }

    eligible.sort((a, b) => score(b).compareTo(score(a)));
    return eligible.take(6).toList(growable: false);
  }
}
