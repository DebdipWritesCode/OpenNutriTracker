import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';

void main() {
  test('treadmill details round-trip through version-tolerant JSON', () {
    const details = ActivityLogDetails(
      kind: ActivityLogKind.treadmill,
      durationSeconds: 1234,
      durationWasEstimated: false,
      profileWeightKg: 72.4,
      estimationMethod: 'acsm-treadmill-metabolic-equation',
      treadmillMode: TreadmillMode.running,
      speedKph: 9.5,
      inclinePercent: 3,
      enteredSpeedUnit: TreadmillSpeedUnit.kilometersPerHour,
    );

    final decoded = ActivityLogDetails.tryParse(details.encode());

    expect(decoded, isNotNull);
    expect(decoded!.kind, ActivityLogKind.treadmill);
    expect(decoded.durationSeconds, 1234);
    expect(decoded.treadmillMode, TreadmillMode.running);
    expect(decoded.speedKph, 9.5);
    expect(decoded.inclinePercent, 3);
  });

  test('invalid or legacy missing metadata is treated as absent', () {
    expect(ActivityLogDetails.tryParse(null), isNull);
    expect(ActivityLogDetails.tryParse('not json'), isNull);
  });
}
