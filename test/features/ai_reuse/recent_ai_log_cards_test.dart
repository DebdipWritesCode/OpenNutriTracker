import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_reuse/domain/recent_ai_log.dart';
import 'package:opennutritracker/features/ai_reuse/presentation/recent_ai_log_cards.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

const _meal = MealEntity(
  code: 'rice',
  name: 'Brown rice with roasted vegetables',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: 'g',
  servingSize: null,
  nutriments: MealNutrimentsEntity(
    energyKcal100: 130,
    carbohydrates100: 28,
    fat100: 0.3,
    proteins100: 2.7,
    sugars100: 0,
    saturatedFat100: 0.1,
    fiber100: 0.4,
  ),
  source: MealSourceEntity.fdc,
);

Widget _app(Widget child) => ChangeNotifierProvider(
  create: (_) => EnergyUnitProvider(),
  child: MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('recent AI cards remain readable on a narrow scaled display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var mealTapped = false;
    var workoutTapped = false;
    final mealLog = RecentAiMealLog(
      groupId: 'meal',
      loggedAt: DateTime(2026, 7, 27, 12),
      intakes: [
        IntakeEntity(
          id: 'rice',
          unit: 'g',
          amount: 180,
          type: IntakeTypeEntity.lunch,
          meal: _meal,
          dateTime: DateTime(2026, 7, 27),
          aiMealGroupId: 'meal',
          aiMealSavedAt: DateTime(2026, 7, 27, 12),
        ),
      ],
    );
    final workoutLog = RecentAiWorkoutLog(
      activityId: 'workout',
      loggedAt: DateTime(2026, 7, 27, 18),
      name: 'Strength workout',
      details: ActivityLogDetails(
        kind: ActivityLogKind.aiStrength,
        durationSeconds: 1800,
        durationWasEstimated: false,
        profileWeightKg: 70,
        estimationMethod: 'test',
        loggedAt: DateTime(2026, 7, 27, 18),
        exercises: const [
          StrengthExerciseLog(
            name: 'Dumbbell shoulder press',
            sets: 3,
            repsPerSet: 8,
            loadValue: 17.5,
            loadUnit: 'kg',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: Column(
              children: [
                RecentAiMealCard(log: mealLog, onTap: () => mealTapped = true),
                RecentAiWorkoutCard(
                  log: workoutLog,
                  onTap: () => workoutTapped = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review and add'), findsNWidgets(2));
    expect(find.textContaining('1 food'), findsOneWidget);
    expect(find.textContaining('1 exercise'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Review and add').first);
    await tester.tap(find.text('Review and add').last);
    expect(mealTapped, isTrue);
    expect(workoutTapped, isTrue);
  });
}
