import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/daily_energy_burn_calc.dart';

void main() {
  final user = UserEntity(
    birthday: DateTime(2001, 1, 1),
    heightCM: 180,
    weightKG: 80,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: UserPALEntity.sedentary,
  );

  group('DailyEnergyBurnCalc', () {
    test('uses the Mifflin-St Jeor resting energy equation', () {
      final expected =
          10 * user.weightKG + 6.25 * user.heightCM - 5 * user.age + 5;

      expect(
        DailyEnergyBurnCalc.dailyRestingKcal(user),
        closeTo(expected, 0.001),
      );
    });

    test('accrues resting energy through a midnight diary day', () {
      final burned = DailyEnergyBurnCalc.restingKcalSoFar(
        dailyRestingKcal: 1800,
        now: DateTime(2026, 7, 27, 12),
      );

      expect(burned, closeTo(900, 0.001));
    });

    test('accrues from the configured diary boundary', () {
      final now = DateTime(2026, 7, 27, 10, 30);
      final start = DailyEnergyBurnCalc.diaryDayStart(
        now,
        dayStartOffsetTotalMinutes: 4 * 60 + 30,
      );
      final burned = DailyEnergyBurnCalc.restingKcalSoFar(
        dailyRestingKcal: 2400,
        now: now,
        dayStartOffsetTotalMinutes: 4 * 60 + 30,
      );

      expect(start, DateTime(2026, 7, 27, 4, 30));
      expect(burned, closeTo(600, 0.001));
    });

    test('uses the previous diary day before a shifted boundary', () {
      final start = DailyEnergyBurnCalc.diaryDayStart(
        DateTime(2026, 7, 27, 2),
        dayStartOffsetTotalMinutes: 4 * 60 + 30,
      );

      expect(start, DateTime(2026, 7, 26, 4, 30));
    });

    test('subtracts the resting share from duration-based activity', () {
      const dailyRestingKcal = 1800.0;
      final activities = [
        UserActivityEntity(
          'strength',
          60,
          280,
          DateTime(2026, 7, 27, 9),
          PhysicalActivityEntity.aiStrength('Strength workout'),
        ),
        UserActivityEntity(
          'tracker',
          0,
          120,
          DateTime(2026, 7, 27, 18),
          PhysicalActivityEntity.custom,
          userKcal: 120,
        ),
      ];

      final active = DailyEnergyBurnCalc.activityKcalAboveRest(
        dailyRestingKcal: dailyRestingKcal,
        activities: activities,
      );

      // 280 gross workout kcal - 75 resting kcal during the hour + 120
      // direct active kcal from a tracker.
      expect(active, closeTo(325, 0.001));
    });

    test('never makes a low-energy session contribution negative', () {
      final activity = UserActivityEntity(
        'low',
        60,
        50,
        DateTime(2026, 7, 27),
        PhysicalActivityEntity.aiStrength('Low estimate'),
      );

      expect(
        DailyEnergyBurnCalc.activityKcalAboveRest(
          dailyRestingKcal: 1800,
          activities: [activity],
        ),
        0,
      );
    });
  });
}
