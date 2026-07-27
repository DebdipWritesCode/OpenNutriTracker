import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';

void main() {
  test('treadmill details round-trip through version-tolerant JSON', () {
    final loggedAt = DateTime(2026, 7, 27, 18, 30);
    final details = ActivityLogDetails(
      kind: ActivityLogKind.treadmill,
      durationSeconds: 1234,
      durationWasEstimated: false,
      profileWeightKg: 72.4,
      estimationMethod: 'acsm-treadmill-metabolic-equation',
      treadmillMode: TreadmillMode.running,
      speedKph: 9.5,
      inclinePercent: 3,
      enteredSpeedUnit: TreadmillSpeedUnit.kilometersPerHour,
      loggedAt: loggedAt,
    );

    final decoded = ActivityLogDetails.tryParse(details.encode());

    expect(decoded, isNotNull);
    expect(decoded!.kind, ActivityLogKind.treadmill);
    expect(decoded.durationSeconds, 1234);
    expect(decoded.treadmillMode, TreadmillMode.running);
    expect(decoded.speedKph, 9.5);
    expect(decoded.inclinePercent, 3);
    expect(decoded.loggedAt, loggedAt);
  });

  test('invalid or legacy missing metadata is treated as absent', () {
    expect(ActivityLogDetails.tryParse(null), isNull);
    expect(ActivityLogDetails.tryParse('not json'), isNull);
  });
}
