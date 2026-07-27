import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('DashboardWidget displays correct data', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: const DashboardWidget(
            totalKcalSupplied: 1500,
            restingKcalBurned: 350,
            activityKcalBurned: 150,
            totalKcalDaily: 2000,
            totalKcalLeft: 1000,
            totalCarbsIntake: 200,
            totalFatsIntake: 50,
            totalProteinsIntake: 100,
            totalCarbsGoal: 250,
            totalFatsGoal: 60,
            totalProteinsGoal: 120,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the supplied and burned calorie values are displayed.
    expect(find.text('1500'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('350 kcal'), findsOneWidget);
    expect(find.text('150 kcal'), findsOneWidget);
    expect(find.text('Resting so far'), findsOneWidget);
    expect(find.text('Activity above rest'), findsOneWidget);
    expect(find.text('Updates throughout your diary day'), findsOneWidget);

    // Verify that the kcal left label is displayed as AnimatedFlipCounter
    final kcalLeftFlipCounter = tester.firstWidget<AnimatedFlipCounter>(
      find.byType(AnimatedFlipCounter),
    );
    expect(kcalLeftFlipCounter.value, 1000);
  });

  testWidgets('energy breakdown fits a narrow screen with larger text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: SingleChildScrollView(
              child: DashboardWidget(
                totalKcalSupplied: 1500,
                restingKcalBurned: 1025,
                activityKcalBurned: 475,
                totalKcalDaily: 2200,
                totalKcalLeft: 700,
                totalCarbsIntake: 200,
                totalFatsIntake: 50,
                totalProteinsIntake: 100,
                totalCarbsGoal: 250,
                totalFatsGoal: 60,
                totalProteinsGoal: 120,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resting so far'), findsOneWidget);
    expect(find.text('Activity above rest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
