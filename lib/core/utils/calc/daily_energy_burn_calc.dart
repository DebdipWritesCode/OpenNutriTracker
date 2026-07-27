import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/bmr_calc.dart';

/// Calculates the two parts of energy burned on the daily dashboard:
///
/// 1. resting energy, accrued continuously across the configured diary day;
/// 2. energy from logged activity above that resting baseline.
///
/// This mirrors the distinction used by Android Health Connect, where total
/// calories include basal and active energy while active calories exclude BMR.
/// The resting estimate uses the Mifflin–St Jeor equation already implemented
/// by [BMRCalc]. No network service, sensor permission, or AI estimate is
/// required.
class DailyEnergyBurnCalc {
  static const int _minutesPerDay = 24 * 60;

  /// Full-day resting energy estimate in kcal/day.
  static double dailyRestingKcal(UserEntity user) {
    return BMRCalc.getBMRMifflinStJeor1990(
      user,
    ).clamp(0, double.infinity).toDouble();
  }

  /// Returns the start of the diary day containing [now].
  ///
  /// The result follows the same configurable boundary used by meals and
  /// activities. For example, with a 04:30 boundary, 02:00 belongs to the
  /// diary day that began at 04:30 on the previous wall-clock date.
  static DateTime diaryDayStart(
    DateTime now, {
    int dayStartOffsetTotalMinutes = 0,
  }) {
    final offset = _validOffset(dayStartOffsetTotalMinutes);
    final shifted = now.subtract(Duration(minutes: offset));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      offset ~/ 60,
      offset % 60,
    );
  }

  /// Resting kcal accrued from the diary-day boundary through [now].
  ///
  /// Constructing the next boundary as a local calendar time keeps the
  /// fraction correct across daylight-saving days that are not exactly
  /// twenty-four elapsed hours.
  static double restingKcalSoFar({
    required double dailyRestingKcal,
    required DateTime now,
    int dayStartOffsetTotalMinutes = 0,
  }) {
    if (!dailyRestingKcal.isFinite || dailyRestingKcal <= 0) return 0;

    final start = diaryDayStart(
      now,
      dayStartOffsetTotalMinutes: dayStartOffsetTotalMinutes,
    );
    final end = DateTime(
      start.year,
      start.month,
      start.day + 1,
      start.hour,
      start.minute,
    );
    final dayMicros = end.difference(start).inMicroseconds;
    if (dayMicros <= 0) return 0;

    final elapsedMicros = now.difference(start).inMicroseconds;
    final fraction = (elapsedMicros / dayMicros).clamp(0.0, 1.0);
    return dailyRestingKcal * fraction;
  }

  /// Extra activity energy to add on top of the continuous resting estimate.
  ///
  /// MET and treadmill session values are gross session energy and already
  /// contain the energy a person would have used at rest during those minutes.
  /// Subtracting that interval's resting share prevents it from being counted
  /// twice. Direct custom kcal entries have no duration, so they are treated as
  /// active energy supplied by the user or their tracker.
  static double activityKcalAboveRest({
    required double dailyRestingKcal,
    required Iterable<UserActivityEntity> activities,
  }) {
    final restingPerMinute = dailyRestingKcal > 0
        ? dailyRestingKcal / _minutesPerDay
        : 0.0;

    return activities.fold<double>(0, (total, activity) {
      final sessionKcal = activity.effectiveBurnedKcal;
      if (!sessionKcal.isFinite || sessionKcal <= 0) return total;
      if (activity.duration <= 0) return total + sessionKcal;

      final restingShare =
          restingPerMinute * activity.duration.clamp(0.0, _minutesPerDay);
      return total +
          (sessionKcal - restingShare).clamp(0, double.infinity).toDouble();
    });
  }

  static int _validOffset(int value) {
    if (value < 0 || value >= _minutesPerDay) return 0;
    return value;
  }
}
