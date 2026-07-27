import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_estimated_activity_usecase.dart';
import 'package:opennutritracker/features/ai_activity/data/ai_activity_api_client.dart';
import 'package:opennutritracker/features/ai_activity/data/dto/ai_activity_analysis_dto.dart';
import 'package:opennutritracker/features/ai_activity/presentation/bloc/ai_activity_bloc.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';

class _Gateway implements AiActivityGateway {
  @override
  Future<AiActivityAnalysis> analyzeActivity({
    required String text,
    required String locale,
  }) async => const AiActivityAnalysis(
    exercises: [
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
    ],
    statedDurationMinutes: null,
    notes: [],
    modelUsed: 'test',
  );
}

class _User implements GetUserUsecase {
  final UserEntity user;

  _User(this.user);

  @override
  UserRepository get userRepository => throw UnimplementedError();

  @override
  Future<UserEntity> getUserData() async => user;

  @override
  Future<bool> hasUserData() async => true;
}

class _Saver implements SaveEstimatedActivityUsecase {
  double? durationMinutes;
  double? burnedKcal;
  String? detailsJson;

  @override
  Future<UserActivityEntity> save({
    required DateTime day,
    required PhysicalActivityEntity activity,
    required double durationMinutes,
    required double burnedKcal,
    required String detailsJson,
  }) async {
    this.durationMinutes = durationMinutes;
    this.burnedKcal = burnedKcal;
    this.detailsJson = detailsJson;
    return UserActivityEntity(
      'saved',
      durationMinutes,
      burnedKcal,
      day,
      activity,
      detailsJson: detailsJson,
    );
  }
}

class _Tokens implements AiAccessTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> save(String token) async {}
}

void main() {
  late _Saver saver;
  late AiActivityBloc bloc;

  setUp(() {
    saver = _Saver();
    final user = UserEntity(
      birthday: DateTime(1996, 1, 1),
      heightCM: 178,
      weightKG: 70,
      gender: UserGenderEntity.male,
      goal: UserWeightGoalEntity.maintainWeight,
      pal: UserPALEntity.sedentary,
    );
    bloc = AiActivityBloc(_Gateway(), _User(user), saver, _Tokens());
  });

  tearDown(() => bloc.close());

  test(
    'reviews parsed exercises with a transparent local duration estimate',
    () async {
      final review = bloc.stream.firstWhere(
        (state) => state.status == AiActivityStatus.review,
      );

      bloc.add(
        const AnalyzeAiActivityRequested(
          'dumbbell press 17.5 kg 3x8 and shoulder press 15 kg 3x8',
          'en',
        ),
      );
      final state = await review;

      expect(state.exercises, hasLength(2));
      expect(state.durationMinutes, 10.5);
      expect(state.durationWasEstimated, isTrue);
      expect(state.estimatedCalories, closeTo(42.875, 0.001));
      expect(state.canSave, isTrue);
    },
  );

  test('saves the reviewed workout and its structured metadata', () async {
    final review = bloc.stream.firstWhere(
      (state) => state.status == AiActivityStatus.review,
    );
    bloc.add(
      const AnalyzeAiActivityRequested(
        'dumbbell press 17.5 kg 3x8 and shoulder press 15 kg 3x8',
        'en',
      ),
    );
    await review;
    final saved = bloc.stream.firstWhere(
      (state) => state.status == AiActivityStatus.saved,
    );

    bloc.add(
      SaveAiActivityRequested(DateTime(2026, 7, 27), 'Strength workout'),
    );
    await saved;

    expect(saver.durationMinutes, 10.5);
    expect(saver.burnedKcal, closeTo(42.875, 0.001));
    final details = ActivityLogDetails.tryParse(saver.detailsJson);
    expect(details?.kind, ActivityLogKind.aiStrength);
    expect(details?.totalSets, 6);
    expect(details?.durationWasEstimated, isTrue);
  });
}
