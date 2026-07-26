import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_photo_picker.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_photo.dart';
import 'package:opennutritracker/features/ai_meal/domain/service/ai_nutrition_resolver.dart';
import 'package:opennutritracker/features/ai_meal/domain/usecase/save_ai_meal_usecase.dart';
import 'package:opennutritracker/features/ai_meal/presentation/ai_meal_screen.dart';
import 'package:opennutritracker/features/ai_meal/presentation/bloc/ai_meal_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _Gateway implements AiMealGateway {
  @override
  Future<AiMealAnalysis> analyzeMeal({
    required String text,
    required String locale,
  }) async => const AiMealAnalysis(
    foods: [
      AiExtractedFood(
        originalText: '100g rice',
        canonicalName: 'rice',
        quantity: 100,
        unit: 'g',
        estimatedGrams: 100,
        preparation: null,
        confidence: 0.98,
        requiresUserConfirmation: false,
      ),
    ],
    notes: [],
    modelUsed: 'test',
  );

  @override
  Future<AiMealAnalysis> analyzePhoto({
    required AiMealPhoto photo,
    required String locale,
  }) => analyzeMeal(text: 'photo', locale: locale);

  @override
  Future<AiMealRefinement> refinePhoto({
    required AiMealPhoto photo,
    required List<AiExtractedFood> currentFoods,
    required List<AiMealCorrectionTurn> correctionHistory,
    required String correction,
    required String locale,
  }) async => const AiMealRefinement(
    foods: [
      AiExtractedFood(
        originalText: '180g rice',
        canonicalName: 'rice',
        quantity: 180,
        unit: 'g',
        estimatedGrams: 180,
        preparation: null,
        confidence: 0.99,
        requiresUserConfirmation: false,
      ),
    ],
    notes: [],
    modelUsed: 'test',
    assistantMessage: 'Updated the rice portion to 180 g.',
  );
}

class _PhotoPicker implements AiMealPhotoPicker {
  @override
  Future<AiMealPhoto?> pick(ImageSource source) async => AiMealPhoto(
    path: '/tmp/test-meal-photo.jpg',
    bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
    mimeType: 'image/jpeg',
    fileName: 'meal-photo.jpg',
  );
}

class _Resolver implements AiNutritionResolver {
  @override
  Future<AiMealDraftItem> resolve(
    AiExtractedFood food, {
    String? query,
  }) async => AiMealDraftItem(
    extractedFood: food,
    searchQuery: query ?? food.canonicalName,
    candidates: const [
      MealEntity(
        code: 'rice-1',
        name: 'Rice, cooked',
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: 'g',
        servingSize: null,
        nutriments: MealNutrimentsEntity(
          energyKcal100: 130,
          carbohydrates100: 28,
          fat100: 0.3,
          proteins100: 2.7,
          sugars100: 0,
          saturatedFat100: 0.1,
          fiber100: 0.4,
        ),
        source: MealSourceEntity.fdc,
      ),
    ],
    selectedCandidateIndex: 0,
    amount: 100,
  );
}

class _Saver implements SaveAiMealUsecase {
  @override
  Future<void> save({
    required List<AiMealDraftItem> items,
    required IntakeTypeEntity intakeType,
    required DateTime day,
  }) async {}
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
    locator.registerFactory<AiMealBloc>(
      () => AiMealBloc(_Gateway(), _Resolver(), _Saver(), _Tokens()),
    );
  });

  tearDown(() => locator.reset());

  testWidgets('shows a labeled description form and analyze action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: AiMealScreenArguments(
              intakeType: IntakeTypeEntity.lunch,
              day: DateTime(2026, 7, 22),
            ),
          ),
          builder: (_) => AiMealScreen(photoPicker: _PhotoPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What did you eat?'), findsOneWidget);
    expect(find.text('Meal description'), findsOneWidget);
    expect(find.text('Analyze meal'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
  });

  testWidgets('analyzes a description into an editable trusted match', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: AiMealScreenArguments(
              intakeType: IntakeTypeEntity.lunch,
              day: DateTime(2026, 7, 22),
            ),
          ),
          builder: (_) => AiMealScreen(photoPicker: _PhotoPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Meal description'),
      '100g rice',
    );
    await tester.tap(find.text('Analyze meal'));
    await tester.pumpAndSettle();

    expect(find.text('Review your meal'), findsOneWidget);
    expect(find.text('Rice, cooked'), findsOneWidget);
    expect(find.text('Ready to save'), findsOneWidget);
    expect(find.text('130 kcal'), findsOneWidget);
    expect(find.text('Save meal'), findsOneWidget);
  });

  testWidgets('captures a photo and shows the editable trusted review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: AiMealScreenArguments(
              intakeType: IntakeTypeEntity.lunch,
              day: DateTime(2026, 7, 25),
            ),
          ),
          builder: (_) => AiMealScreen(photoPicker: _PhotoPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photograph your meal'), findsOneWidget);

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze photo'), findsOneWidget);

    await tester.ensureVisible(find.text('Analyze photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze photo'));
    await tester.pumpAndSettle();

    expect(find.text('Review your meal'), findsOneWidget);
    expect(
      find.textContaining('AI estimated these foods and portions'),
      findsOneWidget,
    );
    expect(find.text('Correct the AI'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rice, cooked'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rice, cooked'), findsOneWidget);
  });

  testWidgets('sends a photo correction and shows the AI update', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: AiMealScreenArguments(
              intakeType: IntakeTypeEntity.lunch,
              day: DateTime(2026, 7, 26),
            ),
          ),
          builder: (_) => AiMealScreen(photoPicker: _PhotoPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Analyze photo'));
    await tester.tap(find.text('Analyze photo'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Correction'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correction'),
      'The rice portion was 180 g.',
    );
    await tester.tap(find.byTooltip('Send correction'));
    await tester.pumpAndSettle();

    expect(find.text('Your correction'), findsOneWidget);
    expect(find.text('The rice portion was 180 g.'), findsOneWidget);
    expect(find.text('AI update'), findsOneWidget);
    expect(find.text('Updated the rice portion to 180 g.'), findsOneWidget);
    expect(find.widgetWithText(TextField, '180'), findsOneWidget);
  });

  testWidgets('photo review does not overflow on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
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
            arguments: AiMealScreenArguments(
              intakeType: IntakeTypeEntity.lunch,
              day: DateTime(2026, 7, 26),
            ),
          ),
          builder: (_) => AiMealScreen(photoPicker: _PhotoPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Take photo'));
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Analyze photo'));
    await tester.tap(find.text('Analyze photo'));
    await tester.pumpAndSettle();

    expect(find.text('Review your meal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
