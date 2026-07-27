import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_activity_usercase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';

class SaveEstimatedActivityUsecase {
  final AddUserActivityUsecase _addActivity;
  final AddTrackedDayUsecase _addTrackedDay;
  final GetKcalGoalUsecase _getKcalGoal;
  final GetMacroGoalUsecase _getMacroGoal;

  SaveEstimatedActivityUsecase(
    this._addActivity,
    this._addTrackedDay,
    this._getKcalGoal,
    this._getMacroGoal,
  );

  Future<UserActivityEntity> save({
    required DateTime day,
    required PhysicalActivityEntity activity,
    required double durationMinutes,
    required double burnedKcal,
    required String detailsJson,
  }) async {
    if (durationMinutes <= 0 || burnedKcal <= 0) {
      throw ArgumentError('Duration and estimated energy must be positive');
    }

    final entity = UserActivityEntity(
      IdGenerator.getUniqueID(),
      durationMinutes,
      burnedKcal,
      day,
      activity,
      detailsJson: detailsJson,
    );
    await _addActivity.addUserActivity(entity);

    if (!await _addTrackedDay.hasTrackedDay(day)) {
      final calorieGoal = await _getKcalGoal.getKcalGoal(
        totalKcalActivitiesParam: 0,
      );
      await _addTrackedDay.addNewTrackedDay(
        day,
        calorieGoal,
        await _getMacroGoal.getCarbsGoal(calorieGoal),
        await _getMacroGoal.getFatsGoal(calorieGoal),
        await _getMacroGoal.getProteinsGoal(calorieGoal),
      );
    }

    await _addTrackedDay.increaseDayCalorieGoal(day, burnedKcal);
    await _addTrackedDay.increaseDayMacroGoals(
      day,
      carbsAmount: MacroCalc.getTotalCarbsGoal(burnedKcal),
      fatAmount: MacroCalc.getTotalFatsGoal(burnedKcal),
      proteinAmount: MacroCalc.getTotalProteinsGoal(burnedKcal),
    );
    return entity;
  }
}
