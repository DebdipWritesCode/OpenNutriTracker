import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';

/// A complete, previously confirmed AI meal that can be reopened as an
/// editable review without calling the AI or a nutrition service again.
class RecentAiMealLog extends Equatable {
  final String groupId;
  final DateTime loggedAt;
  final List<IntakeEntity> intakes;

  const RecentAiMealLog({
    required this.groupId,
    required this.loggedAt,
    required this.intakes,
  });

  double get totalKcal =>
      intakes.fold(0, (total, intake) => total + intake.totalKcal);

  @override
  List<Object?> get props => [groupId, loggedAt, intakes];
}

/// A complete, previously confirmed AI strength workout. Calories are not
/// reused: selecting this log rebuilds the review with the active profile's
/// current body weight.
class RecentAiWorkoutLog extends Equatable {
  final String activityId;
  final DateTime loggedAt;
  final String name;
  final ActivityLogDetails details;

  const RecentAiWorkoutLog({
    required this.activityId,
    required this.loggedAt,
    required this.name,
    required this.details,
  });

  double get durationMinutes => details.durationSeconds / 60;

  @override
  List<Object?> get props => [activityId, loggedAt, name, details.encode()];
}
