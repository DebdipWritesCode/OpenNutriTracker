import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/utils/calc/treadmill_energy_calc.dart';

void main() {
  group('TreadmillEnergyCalc', () {
    test('converts mph to km/h and back', () {
      final kph = TreadmillEnergyCalc.toKilometersPerHour(
        5,
        TreadmillSpeedUnit.milesPerHour,
      );

      expect(kph, closeTo(8.04672, 0.00001));
      expect(
        TreadmillEnergyCalc.fromKilometersPerHour(
          kph,
          TreadmillSpeedUnit.milesPerHour,
        ),
        closeTo(5, 0.00001),
      );
    });

    test('uses the ACSM running equation', () {
      final oxygen = TreadmillEnergyCalc.oxygenCostMlKgMin(
        mode: TreadmillMode.running,
        speedKph: 10,
        inclinePercent: 0,
      );
      final calories = TreadmillEnergyCalc.calories(
        mode: TreadmillMode.running,
        speedKph: 10,
        inclinePercent: 0,
        weightKg: 70,
        durationMinutes: 30,
      );

      expect(oxygen, closeTo(36.8333, 0.001));
      expect(calories, closeTo(386.75, 0.01));
    });

    test('walking energy includes incline', () {
      final oxygen = TreadmillEnergyCalc.oxygenCostMlKgMin(
        mode: TreadmillMode.walking,
        speedKph: 5,
        inclinePercent: 10,
      );
      final calories = TreadmillEnergyCalc.calories(
        mode: TreadmillMode.walking,
        speedKph: 5,
        inclinePercent: 10,
        weightKg: 70,
        durationMinutes: 30,
      );

      expect(oxygen, closeTo(26.8333, 0.001));
      expect(calories, closeTo(281.75, 0.01));
    });
  });
}
