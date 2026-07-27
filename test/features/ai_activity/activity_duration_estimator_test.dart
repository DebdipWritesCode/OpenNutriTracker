import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/ai_activity/data/dto/ai_activity_analysis_dto.dart';
import 'package:opennutritracker/features/ai_activity/domain/activity_duration_estimator.dart';

void main() {
  test('estimates the example two-exercise workout deterministically', () {
    const exercises = [
      AiExtractedExercise(
        originalText: 'dumbbell press 17.5 kg for 3 sets of 8',
        canonicalName: 'dumbbell press',
        sets: 3,
        repsPerSet: 8,
        loadValue: 17.5,
        loadUnit: 'kg',
        confidence: 0.98,
        requiresUserConfirmation: false,
      ),
      AiExtractedExercise(
        originalText: 'shoulder press 15 kg for 3 sets of 8',
        canonicalName: 'shoulder press',
        sets: 3,
        repsPerSet: 8,
        loadValue: 15,
        loadUnit: 'kg',
        confidence: 0.98,
        requiresUserConfirmation: false,
      ),
    ];

    final result = ActivityDurationEstimator.estimate(exercises);

    expect(result.minutes, 10.5);
    expect(result.usedFallback, isFalse);
  });

  test('marks fallback duration when sets or reps are missing', () {
    const exercise = AiExtractedExercise(
      originalText: 'some shoulder press',
      canonicalName: 'shoulder press',
      sets: null,
      repsPerSet: null,
      loadValue: null,
      loadUnit: null,
      confidence: 0.5,
      requiresUserConfirmation: true,
    );

    final result = ActivityDurationEstimator.estimate(const [exercise]);

    expect(result.minutes, 5);
    expect(result.usedFallback, isTrue);
  });
}
