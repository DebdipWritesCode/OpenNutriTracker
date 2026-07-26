import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_photo.dart';
import 'package:opennutritracker/features/ai_meal/domain/service/ai_nutrition_resolver.dart';
import 'package:opennutritracker/features/ai_meal/domain/usecase/save_ai_meal_usecase.dart';
import 'package:opennutritracker/features/ai_meal/presentation/bloc/ai_meal_bloc.dart';

const _food = AiExtractedFood(
  originalText: '100g rice',
  canonicalName: 'rice',
  quantity: 100,
  unit: 'g',
  estimatedGrams: 100,
  preparation: null,
  confidence: 0.98,
  requiresUserConfirmation: false,
);

MealEntity _meal() => const MealEntity(
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
);

class _Gateway implements AiMealGateway {
  AiApiException? failure;
  List<AiExtractedFood>? refinementFoods;
  List<AiMealCorrectionTurn>? refinementHistory;
  String? capturedCorrection;

  @override
  Future<AiMealAnalysis> analyzeMeal({
    required String text,
    required String locale,
  }) async {
    if (failure != null) throw failure!;
    return const AiMealAnalysis(foods: [_food], notes: [], modelUsed: 'test');
  }

  @override
  Future<AiMealAnalysis> analyzePhoto({
    required AiMealPhoto photo,
    required String locale,
  }) async {
    if (failure != null) throw failure!;
    return const AiMealAnalysis(foods: [_food], notes: [], modelUsed: 'test');
  }

  @override
  Future<AiMealRefinement> refinePhoto({
    required AiMealPhoto photo,
    required List<AiExtractedFood> currentFoods,
    required List<AiMealCorrectionTurn> correctionHistory,
    required String correction,
    required String locale,
  }) async {
    if (failure != null) throw failure!;
    refinementFoods = currentFoods;
    refinementHistory = correctionHistory;
    capturedCorrection = correction;
    return const AiMealRefinement(
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
}

class _Resolver implements AiNutritionResolver {
  @override
  Future<AiMealDraftItem> resolve(
    AiExtractedFood food, {
    String? query,
  }) async => AiMealDraftItem(
    extractedFood: food,
    searchQuery: query ?? food.canonicalName,
    candidates: [_meal()],
    selectedCandidateIndex: 0,
    amount: 100,
  );
}

class _Saver implements SaveAiMealUsecase {
  var calls = 0;

  @override
  Future<void> save({
    required List<AiMealDraftItem> items,
    required IntakeTypeEntity intakeType,
    required DateTime day,
  }) async {
    calls++;
  }
}

class _TokenStore implements AiAccessTokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String token) async => this.token = token;
}

void main() {
  late _Gateway gateway;
  late _Saver saver;
  late _TokenStore tokens;
  late AiMealBloc bloc;

  setUp(() {
    gateway = _Gateway();
    saver = _Saver();
    tokens = _TokenStore();
    bloc = AiMealBloc(gateway, _Resolver(), saver, tokens);
  });

  tearDown(() => bloc.close());

  test('analyzes and resolves foods before review', () async {
    final review = bloc.stream.firstWhere(
      (state) => state.status == AiMealStatus.review,
    );

    bloc.add(const AnalyzeAiMealRequested(text: '100g rice', locale: 'en'));
    final state = await review;

    expect(state.items, hasLength(1));
    expect(state.items.single.selectedMeal?.name, 'Rice, cooked');
    expect(state.items.single.calories, 130);
    expect(state.canSave, isTrue);
  });

  test('surfaces authentication failures', () async {
    gateway.failure = const AiApiException(
      AiApiFailureKind.authentication,
      'Token required',
    );
    final failure = bloc.stream.firstWhere(
      (state) => state.status == AiMealStatus.failure,
    );

    bloc.add(const AnalyzeAiMealRequested(text: 'rice', locale: 'en'));
    final state = await failure;

    expect(state.authenticationRequired, isTrue);
    expect(state.errorMessage, 'Token required');
  });

  test('analyzes a photo before trusted nutrition resolution', () async {
    final review = bloc.stream.firstWhere(
      (state) => state.status == AiMealStatus.review,
    );
    final photo = AiMealPhoto(
      path: '/tmp/meal.jpg',
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
      mimeType: 'image/jpeg',
      fileName: 'meal-photo.jpg',
    );

    bloc.add(AnalyzeAiMealPhotoRequested(photo: photo, locale: 'en'));
    final state = await review;

    expect(state.photo, photo);
    expect(state.items.single.selectedMeal?.source, MealSourceEntity.fdc);
    expect(state.items.single.calories, 130);
    expect(state.canSave, isTrue);
  });

  test(
    'refines a photo while preserving its trusted nutrition match',
    () async {
      final photoReview = bloc.stream.firstWhere(
        (state) => state.status == AiMealStatus.review,
      );
      final photo = AiMealPhoto(
        path: '/tmp/meal.jpg',
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
        mimeType: 'image/jpeg',
        fileName: 'meal-photo.jpg',
      );
      bloc.add(AnalyzeAiMealPhotoRequested(photo: photo, locale: 'en'));
      await photoReview;

      final refined = bloc.stream.firstWhere(
        (state) =>
            state.status == AiMealStatus.review &&
            state.correctionHistory.isNotEmpty,
      );
      bloc.add(
        const RefineAiMealPhotoRequested(
          correction: 'The rice portion was 180 g.',
          locale: 'en',
        ),
      );
      final state = await refined;

      expect(gateway.capturedCorrection, 'The rice portion was 180 g.');
      expect(gateway.refinementFoods?.single.estimatedGrams, 100);
      expect(gateway.refinementHistory, isEmpty);
      expect(state.items.single.amount, 180);
      expect(state.items.single.selectedMeal?.source, MealSourceEntity.fdc);
      expect(
        state.correctionHistory.single.assistantMessage,
        contains('180 g'),
      );
      expect(state.canSave, isTrue);
    },
  );

  test('saves every ready item through the save use case', () async {
    final review = bloc.stream.firstWhere(
      (state) => state.status == AiMealStatus.review,
    );
    bloc.add(const AnalyzeAiMealRequested(text: '100g rice', locale: 'en'));
    await review;
    final saved = bloc.stream.firstWhere(
      (state) => state.status == AiMealStatus.saved,
    );

    bloc.add(
      SaveAiMealRequested(
        intakeType: IntakeTypeEntity.lunch,
        day: DateTime(2026, 7, 22),
      ),
    );
    await saved;

    expect(saver.calls, 1);
  });
}
