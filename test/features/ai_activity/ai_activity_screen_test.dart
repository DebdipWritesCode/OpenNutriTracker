import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/ai_activity/data/ai_activity_api_client.dart';
import 'package:opennutritracker/features/ai_activity/data/dto/ai_activity_analysis_dto.dart';
import 'package:opennutritracker/features/ai_activity/presentation/ai_activity_screen.dart';
import 'package:opennutritracker/features/ai_activity/presentation/bloc/ai_activity_bloc.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_reuse/domain/recent_ai_log.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

class _Gateway implements AiActivityGateway {
  @override
  Future<AiActivityAnalysis> analyzeActivity({
    required String text,
    required String locale,
  }) async => const AiActivityAnalysis(
    exercises: [
      AiExtractedExercise(
        originalText: 'dumbbell press 17.5 kg 3x8',
        canonicalName: 'dumbbell press',
        sets: 3,
        repsPerSet: 8,
        loadValue: 17.5,
        loadUnit: 'kg',
        confidence: 0.98,
        requiresUserConfirmation: false,
      ),
      AiExtractedExercise(
        originalText: 'shoulder press 15 kg 3x8',
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
  @override
  UserRepository get userRepository => throw UnimplementedError();

  @override
  Future<UserEntity> getUserData() async => UserEntity(
    birthday: DateTime(1996, 1, 1),
    heightCM: 178,
    weightKG: 70,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: UserPALEntity.sedentary,
  );

  @override
  Future<bool> hasUserData() async => true;
}

class _Saver implements SaveEstimatedActivityUsecase {
  @override
  Future<UserActivityEntity> save({
    required DateTime day,
    required PhysicalActivityEntity activity,
    required double durationMinutes,
    required double burnedKcal,
    required String detailsJson,
  }) async => UserActivityEntity(
    'saved',
    durationMinutes,
    burnedKcal,
    day,
    activity,
    detailsJson: detailsJson,
  );
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
  setUp(() async {
    await locator.reset();
    locator.registerFactory<AiActivityBloc>(
      () => AiActivityBloc(_Gateway(), _User(), _Saver(), _Tokens()),
    );
  });

  tearDown(() => locator.reset());

  testWidgets('workout review remains scrollable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: AiActivityScreenArguments(day: DateTime(2026, 7, 27)),
            ),
            builder: (_) => const AiActivityScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Workout description'),
      'dumbbell press 17.5 kg 3x8 and shoulder press 15 kg 3x8',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze workout'));
    await tester.pumpAndSettle();

    expect(find.text('Review your workout'), findsOneWidget);
    expect(find.text('Save workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a recent workout without calling AI again', (
    tester,
  ) async {
    final recent = RecentAiWorkoutLog(
      activityId: 'recent',
      loggedAt: DateTime(2026, 7, 27, 18),
      name: 'Strength workout',
      details: ActivityLogDetails(
        kind: ActivityLogKind.aiStrength,
        durationSeconds: 1800,
        durationWasEstimated: false,
        profileWeightKg: 80,
        estimationMethod: 'test',
        loggedAt: DateTime(2026, 7, 27, 18),
        exercises: const [
          StrengthExerciseLog(
            name: 'Dumbbell press',
            sets: 3,
            repsPerSet: 8,
            loadValue: 17.5,
            loadUnit: 'kg',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: AiActivityScreenArguments(
                day: DateTime(2026, 7, 28),
                recentLog: recent,
              ),
            ),
            builder: (_) => const AiActivityScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review your workout'), findsOneWidget);
    expect(find.text('Dumbbell press'), findsOneWidget);
    expect(find.text('Save workout'), findsOneWidget);
    expect(find.text('Analyze workout'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
