import 'dart:math';

import 'package:opennutritracker/features/ai_activity/data/dto/ai_activity_analysis_dto.dart';

class ActivityDurationEstimate {
  final double minutes;
  final bool usedFallback;

  const ActivityDurationEstimate(this.minutes, this.usedFallback);
}

class ActivityDurationEstimator {
  static const int secondsPerRep = 4;
  static const int restSecondsBetweenSets = 90;
  static const int transitionSeconds = 60;
  static const int fallbackSecondsPerExercise = 5 * 60;

  static ActivityDurationEstimate estimate(
    List<AiExtractedExercise> exercises,
  ) {
    var seconds = 0;
    var usedFallback = false;
    for (final exercise in exercises) {
      final sets = exercise.sets;
      final reps = exercise.repsPerSet;
      if (sets == null || reps == null) {
        seconds += fallbackSecondsPerExercise;
        usedFallback = true;
        continue;
      }
      seconds += sets * reps * secondsPerRep;
      seconds += max(0, sets - 1) * restSecondsBetweenSets;
    }
    seconds += max(0, exercises.length - 1) * transitionSeconds;
    final roundedHalfMinutes = (seconds / 30).ceil() / 2;
    return ActivityDurationEstimate(max(1, roundedHalfMinutes), usedFallback);
  }
}
