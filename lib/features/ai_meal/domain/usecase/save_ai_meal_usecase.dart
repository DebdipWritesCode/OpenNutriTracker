import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';

class SaveAiMealUsecase {
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _addTrackedDay;
  final GetKcalGoalUsecase _getKcalGoal;
  final GetMacroGoalUsecase _getMacroGoal;

  SaveAiMealUsecase(
    this._addIntake,
    this._addTrackedDay,
    this._getKcalGoal,
    this._getMacroGoal,
  );

  Future<void> save({
    required List<AiMealDraftItem> items,
    required IntakeTypeEntity intakeType,
    required DateTime day,
  }) async {
    if (items.isEmpty || items.any((item) => !item.isReady)) {
      throw ArgumentError(
        'Every AI meal item must have a nutrition match and amount',
      );
    }

    if (!await _addTrackedDay.hasTrackedDay(day)) {
      final calorieGoal = await _getKcalGoal.getKcalGoal();
      await _addTrackedDay.addNewTrackedDay(
        day,
        calorieGoal,
        await _getMacroGoal.getCarbsGoal(calorieGoal),
        await _getMacroGoal.getFatsGoal(calorieGoal),
        await _getMacroGoal.getProteinsGoal(calorieGoal),
      );
    }

    for (final item in items) {
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
        unit: item.amountUnit,
        amount: item.amount!,
        type: intakeType,
        meal: item.selectedMeal!,
        dateTime: day,
      );
      await _addIntake.addIntake(intake);
      await _addTrackedDay.addDayCaloriesTracked(day, intake.totalKcal);
      await _addTrackedDay.addDayMacrosTracked(
        day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
      );
    }
  }
}
