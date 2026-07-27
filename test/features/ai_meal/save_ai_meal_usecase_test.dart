import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
import 'package:opennutritracker/features/ai_meal/domain/usecase/save_ai_meal_usecase.dart';

class _Intakes implements AddIntakeUsecase {
  final saved = <IntakeEntity>[];

  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    saved.add(intakeEntity);
  }
}

class _TrackedDays implements AddTrackedDayUsecase {
  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addDayCaloriesTracked(
    DateTime day,
    double caloriesTracked,
  ) async {}

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KcalGoal implements GetKcalGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MacroGoal implements GetMacroGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 130,
  carbohydrates100: 28,
  fat100: 0.3,
  proteins100: 2.7,
  sugars100: 0,
  saturatedFat100: 0.1,
  fiber100: 0.4,
);

AiMealDraftItem _item(String code, String name, double amount) {
  final food = AiExtractedFood(
    originalText: name,
    canonicalName: name,
    quantity: amount,
    unit: 'g',
    estimatedGrams: amount,
    preparation: null,
    confidence: 1,
    requiresUserConfirmation: false,
  );
  return AiMealDraftItem(
    extractedFood: food,
    searchQuery: name,
    candidates: [
      MealEntity(
        code: code,
        name: name,
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: 'g',
        servingSize: null,
        nutriments: _nutriments,
        source: MealSourceEntity.fdc,
      ),
    ],
    selectedCandidateIndex: 0,
    amount: amount,
  );
}

void main() {
  test(
    'marks every food from one AI confirmation with one recent-log id',
    () async {
      final intakes = _Intakes();
      final usecase = SaveAiMealUsecase(
        intakes,
        _TrackedDays(),
        _KcalGoal(),
        _MacroGoal(),
      );

      await usecase.save(
        items: [_item('rice', 'Rice', 180), _item('dal', 'Dal', 150)],
        intakeType: IntakeTypeEntity.lunch,
        day: DateTime(2026, 7, 27),
      );

      expect(intakes.saved, hasLength(2));
      expect(intakes.saved.first.aiMealGroupId, isNotNull);
      expect(
        intakes.saved.map((intake) => intake.aiMealGroupId).toSet(),
        hasLength(1),
      );
      expect(
        intakes.saved.map((intake) => intake.aiMealSavedAt).toSet(),
        hasLength(1),
      );
      expect(
        intakes.saved.every((intake) => intake.aiMealSavedAt != null),
        isTrue,
      );
    },
  );
}
