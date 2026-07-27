import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/treadmill_activity/presentation/treadmill_activity_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

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

class _Config implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.system);
}

void main() {
  setUp(() async {
    await locator.reset();
    locator.registerSingleton<GetUserUsecase>(_User());
    locator.registerSingleton<GetConfigUsecase>(_Config());
  });

  tearDown(() => locator.reset());

  testWidgets('shows treadmill-specific inputs without a quantity field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const activity = PhysicalActivityEntity(
      '12180',
      'running',
      'on treadmill, general',
      8,
      [],
      PhysicalActivityTypeEntity.running,
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
              arguments: TreadmillActivityScreenArguments(
                activity: activity,
                day: DateTime(2026, 7, 27),
              ),
            ),
            builder: (_) => const TreadmillActivityScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minutes'), findsOneWidget);
    expect(find.text('Seconds'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Incline'), findsOneWidget);
    expect(find.text('Quantity'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.textContaining('kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
