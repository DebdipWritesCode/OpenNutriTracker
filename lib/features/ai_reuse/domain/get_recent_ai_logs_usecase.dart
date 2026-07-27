import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_activity_usecase.dart';
import 'package:opennutritracker/features/ai_reuse/domain/recent_ai_log.dart';

class GetRecentAiLogsUsecase {
  static const defaultLimit = 8;

  final GetIntakeUsecase _getIntakes;
  final GetUserActivityUsecase _getActivities;

  const GetRecentAiLogsUsecase(this._getIntakes, this._getActivities);

  Future<List<RecentAiMealLog>> getMeals({int limit = defaultLimit}) async =>
      buildMeals(await _getIntakes.getAllIntakes(), limit: limit);

  Future<List<RecentAiWorkoutLog>> getWorkouts({
    int limit = defaultLimit,
  }) async =>
      buildWorkouts(await _getActivities.getAllUserActivities(), limit: limit);

  /// Groups foods by their AI confirmation id, orders them by the actual save
  /// time, and collapses exact repeats so "recents" stays useful rather than
  /// growing a duplicate row every day.
  static List<RecentAiMealLog> buildMeals(
    Iterable<IntakeEntity> intakes, {
    int limit = defaultLimit,
  }) {
    if (limit <= 0) return const [];
    final grouped = <String, List<IntakeEntity>>{};
    for (final intake in intakes) {
      final groupId = intake.aiMealGroupId;
      if (groupId == null || groupId.isEmpty) continue;
      grouped.putIfAbsent(groupId, () => []).add(intake);
    }

    final logs = grouped.entries.map((entry) {
      final entries = entry.value;
      final loggedAt = entries
          .map((intake) => intake.aiMealSavedAt ?? intake.dateTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return RecentAiMealLog(
        groupId: entry.key,
        loggedAt: loggedAt,
        intakes: List.unmodifiable(entries),
      );
    }).toList()..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final signatures = <String>{};
    return logs
        .where((log) => signatures.add(_mealSignature(log)))
        .take(limit)
        .toList(growable: false);
  }

  static List<RecentAiWorkoutLog> buildWorkouts(
    Iterable<UserActivityEntity> activities, {
    int limit = defaultLimit,
  }) {
    if (limit <= 0) return const [];
    final logs = <RecentAiWorkoutLog>[];
    for (final activity in activities) {
      final details = activity.details;
      if (details == null ||
          details.kind != ActivityLogKind.aiStrength ||
          details.exercises.isEmpty) {
        continue;
      }
      logs.add(
        RecentAiWorkoutLog(
          activityId: activity.id,
          loggedAt: details.loggedAt ?? activity.date,
          name: activity.physicalActivityEntity.specificActivity,
          details: details,
        ),
      );
    }
    logs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final signatures = <String>{};
    return logs
        .where((log) => signatures.add(_workoutSignature(log)))
        .take(limit)
        .toList(growable: false);
  }

  static String _mealSignature(RecentAiMealLog log) {
    final items =
        log.intakes
            .map(
              (intake) =>
                  '${intake.meal.source.name}:'
                  '${(intake.meal.code ?? intake.meal.name ?? '').toLowerCase()}:'
                  '${intake.amount.toStringAsFixed(3)}:${intake.unit.toLowerCase()}',
            )
            .toList()
          ..sort();
    return items.join('|');
  }

  static String _workoutSignature(RecentAiWorkoutLog log) {
    final exercises =
        log.details.exercises
            .map(
              (exercise) =>
                  '${exercise.name.trim().toLowerCase()}:'
                  '${exercise.sets}:${exercise.repsPerSet}:'
                  '${exercise.loadValue?.toStringAsFixed(3) ?? ''}:'
                  '${exercise.loadUnit?.toLowerCase() ?? ''}',
            )
            .toList()
          ..sort();
    return '${log.details.durationSeconds}|${exercises.join('|')}';
  }
}
