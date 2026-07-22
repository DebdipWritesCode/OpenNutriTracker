import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
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

  @override
  Future<AiMealAnalysis> analyzeMeal({
    required String text,
    required String locale,
  }) async {
    if (failure != null) throw failure!;
    return const AiMealAnalysis(foods: [_food], notes: [], modelUsed: 'test');
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
