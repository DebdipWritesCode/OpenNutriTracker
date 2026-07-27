import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_reuse/domain/get_recent_ai_logs_usecase.dart';

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 100,
  carbohydrates100: 10,
  fat100: 2,
  proteins100: 4,
  sugars100: 1,
  saturatedFat100: 0.5,
  fiber100: 1,
);

MealEntity _meal(String code, String name) => MealEntity(
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
);

IntakeEntity _intake({
  required String id,
  required String group,
  required DateTime savedAt,
  required MealEntity meal,
  double amount = 100,
}) => IntakeEntity(
  id: id,
  unit: 'g',
  amount: amount,
  type: IntakeTypeEntity.lunch,
  meal: meal,
  dateTime: DateTime(2026, 7, 27),
  aiMealGroupId: group,
  aiMealSavedAt: savedAt,
);

ActivityLogDetails _workoutDetails({
  required DateTime loggedAt,
  int durationSeconds = 1800,
  double load = 17.5,
}) => ActivityLogDetails(
  kind: ActivityLogKind.aiStrength,
  durationSeconds: durationSeconds,
  durationWasEstimated: false,
  profileWeightKg: 70,
  estimationMethod: 'test',
  loggedAt: loggedAt,
  exercises: [
    StrengthExerciseLog(
      name: 'Dumbbell press',
      sets: 3,
      repsPerSet: 8,
      loadValue: load,
      loadUnit: 'kg',
    ),
  ],
);

void main() {
  test('groups complete AI meals and keeps the newest exact repeat', () {
    final rice = _meal('rice', 'Rice');
    final dal = _meal('dal', 'Dal');
    final old = DateTime(2026, 7, 26, 12);
    final recent = DateTime(2026, 7, 27, 12);

    final logs = GetRecentAiLogsUsecase.buildMeals([
      _intake(id: 'old-rice', group: 'old', savedAt: old, meal: rice),
      _intake(id: 'old-dal', group: 'old', savedAt: old, meal: dal),
      _intake(id: 'new-rice', group: 'new', savedAt: recent, meal: rice),
      _intake(id: 'new-dal', group: 'new', savedAt: recent, meal: dal),
      IntakeEntity(
        id: 'manual',
        unit: 'g',
        amount: 100,
        type: IntakeTypeEntity.lunch,
        meal: rice,
        dateTime: recent,
      ),
    ]);

    expect(logs, hasLength(1));
    expect(logs.single.groupId, 'new');
    expect(logs.single.intakes, hasLength(2));
    expect(logs.single.totalKcal, 200);
  });

  test('keeps distinct portions as distinct recent meals', () {
    final rice = _meal('rice', 'Rice');
    final logs = GetRecentAiLogsUsecase.buildMeals([
      _intake(
        id: 'one',
        group: 'one',
        savedAt: DateTime(2026, 7, 27, 8),
        meal: rice,
      ),
      _intake(
        id: 'two',
        group: 'two',
        savedAt: DateTime(2026, 7, 27, 9),
        meal: rice,
        amount: 150,
      ),
    ]);

    expect(logs.map((log) => log.groupId), ['two', 'one']);
  });

  test('keeps newest exact workout and ignores non-AI activity logs', () {
    final oldDetails = _workoutDetails(loggedAt: DateTime(2026, 7, 26, 18));
    final newDetails = _workoutDetails(loggedAt: DateTime(2026, 7, 27, 18));
    final logs = GetRecentAiLogsUsecase.buildWorkouts([
      UserActivityEntity(
        'old',
        30,
        120,
        DateTime(2026, 7, 26),
        PhysicalActivityEntity.aiStrength('Strength workout'),
        detailsJson: oldDetails.encode(),
      ),
      UserActivityEntity(
        'new',
        30,
        120,
        DateTime(2026, 7, 27),
        PhysicalActivityEntity.aiStrength('Strength workout'),
        detailsJson: newDetails.encode(),
      ),
      UserActivityEntity(
        'run',
        20,
        200,
        DateTime(2026, 7, 27),
        const PhysicalActivityEntity(
          '12150',
          'running',
          'running',
          8,
          [],
          PhysicalActivityTypeEntity.running,
        ),
      ),
    ]);

    expect(logs, hasLength(1));
    expect(logs.single.activityId, 'new');
    expect(logs.single.details.exercises.single.loadValue, 17.5);
  });
}
