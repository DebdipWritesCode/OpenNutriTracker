import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';

class TreadmillEnergyCalc {
  static const double kilometersPerMile = 1.609344;

  static double toKilometersPerHour(double speed, TreadmillSpeedUnit unit) =>
      unit == TreadmillSpeedUnit.kilometersPerHour
      ? speed
      : speed * kilometersPerMile;

  static double fromKilometersPerHour(
    double speedKph,
    TreadmillSpeedUnit unit,
  ) => unit == TreadmillSpeedUnit.kilometersPerHour
      ? speedKph
      : speedKph / kilometersPerMile;

  /// ACSM treadmill metabolic equations.
  ///
  /// Speed is converted to metres/minute and grade is represented as a
  /// fraction. The result is estimated oxygen consumption in ml/kg/min.
  /// See the equation descriptions referenced in docs/ai_implementation_status.md.
  static double oxygenCostMlKgMin({
    required TreadmillMode mode,
    required double speedKph,
    required double inclinePercent,
  }) {
    final speedMetresPerMinute = speedKph * 1000 / 60;
    final grade = inclinePercent / 100;
    return switch (mode) {
      TreadmillMode.walking =>
        0.1 * speedMetresPerMinute + 1.8 * speedMetresPerMinute * grade + 3.5,
      TreadmillMode.running =>
        0.2 * speedMetresPerMinute + 0.9 * speedMetresPerMinute * grade + 3.5,
    };
  }

  /// Converts estimated oxygen use to gross kcal using 5 kcal per litre O2.
  static double calories({
    required TreadmillMode mode,
    required double speedKph,
    required double inclinePercent,
    required double weightKg,
    required double durationMinutes,
  }) {
    final oxygenCost = oxygenCostMlKgMin(
      mode: mode,
      speedKph: speedKph,
      inclinePercent: inclinePercent,
    );
    return oxygenCost * weightKg / 1000 * 5 * durationMinutes;
  }
}
