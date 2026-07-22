import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
import 'package:opennutritracker/features/ai_meal/domain/service/ai_nutrition_resolver.dart';
import 'package:opennutritracker/features/ai_meal/domain/usecase/save_ai_meal_usecase.dart';

enum AiMealStatus { initial, analyzing, review, saving, saved, failure }

sealed class AiMealEvent extends Equatable {
  const AiMealEvent();

  @override
  List<Object?> get props => [];
}

class AnalyzeAiMealRequested extends AiMealEvent {
  final String text;
  final String locale;

  const AnalyzeAiMealRequested({required this.text, required this.locale});

  @override
  List<Object?> get props => [text, locale];
}

class AiMealAmountChanged extends AiMealEvent {
  final int index;
  final double? amount;

  const AiMealAmountChanged(this.index, this.amount);

  @override
  List<Object?> get props => [index, amount];
}

class AiMealCandidateSelected extends AiMealEvent {
  final int itemIndex;
  final int candidateIndex;

  const AiMealCandidateSelected(this.itemIndex, this.candidateIndex);

  @override
  List<Object?> get props => [itemIndex, candidateIndex];
}

class AiMealItemRemoved extends AiMealEvent {
  final int index;

  const AiMealItemRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

class AiMealMatchRequested extends AiMealEvent {
  final int index;
  final String query;

  const AiMealMatchRequested(this.index, this.query);

  @override
  List<Object?> get props => [index, query];
}

class SaveAiMealRequested extends AiMealEvent {
  final IntakeTypeEntity intakeType;
  final DateTime day;

  const SaveAiMealRequested({required this.intakeType, required this.day});

  @override
  List<Object?> get props => [intakeType, day];
}

class AiAccessTokenSubmitted extends AiMealEvent {
  final String token;
  final String locale;

  const AiAccessTokenSubmitted({required this.token, required this.locale});

  @override
  List<Object?> get props => [token, locale];
}

class AiMealState extends Equatable {
  final AiMealStatus status;
  final String description;
  final List<AiMealDraftItem> items;
  final List<String> notes;
  final String? errorMessage;
  final bool authenticationRequired;

  const AiMealState({
    this.status = AiMealStatus.initial,
    this.description = '',
    this.items = const [],
    this.notes = const [],
    this.errorMessage,
    this.authenticationRequired = false,
  });

  bool get canSave =>
      status == AiMealStatus.review &&
      items.isNotEmpty &&
      items.every((item) => item.isReady && !item.isResolving);

  AiMealState copyWith({
    AiMealStatus? status,
    String? description,
    List<AiMealDraftItem>? items,
    List<String>? notes,
    String? errorMessage,
    bool clearError = false,
    bool? authenticationRequired,
  }) => AiMealState(
    status: status ?? this.status,
    description: description ?? this.description,
    items: items ?? this.items,
    notes: notes ?? this.notes,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    authenticationRequired:
        authenticationRequired ?? this.authenticationRequired,
  );

  @override
  List<Object?> get props => [
    status,
    description,
    items,
    notes,
    errorMessage,
    authenticationRequired,
  ];
}

class AiMealBloc extends Bloc<AiMealEvent, AiMealState> {
  final AiMealGateway _gateway;
  final AiNutritionResolver _resolver;
  final SaveAiMealUsecase _saveMeal;
  final AiAccessTokenStore _tokenStore;

  AiMealBloc(this._gateway, this._resolver, this._saveMeal, this._tokenStore)
    : super(const AiMealState()) {
    on<AnalyzeAiMealRequested>(_analyze);
    on<AiMealAmountChanged>(_changeAmount);
    on<AiMealCandidateSelected>(_selectCandidate);
    on<AiMealItemRemoved>(_removeItem);
    on<AiMealMatchRequested>(_resolveMatch);
    on<SaveAiMealRequested>(_save);
    on<AiAccessTokenSubmitted>(_saveToken);
  }

  Future<void> _analyze(
    AnalyzeAiMealRequested event,
    Emitter<AiMealState> emit,
  ) async {
    final description = event.text.trim();
    if (description.length < 2) {
      emit(
        state.copyWith(
          status: AiMealStatus.failure,
          errorMessage: 'Describe at least one food or drink.',
          authenticationRequired: false,
        ),
      );
      return;
    }

    emit(AiMealState(status: AiMealStatus.analyzing, description: description));
    try {
      final analysis = await _gateway.analyzeMeal(
        text: description,
        locale: event.locale,
      );
      if (analysis.foods.isEmpty) {
        emit(
          AiMealState(
            status: AiMealStatus.failure,
            description: description,
            errorMessage:
                'No foods were found. Add amounts or food names and try again.',
          ),
        );
        return;
      }

      final drafts = <AiMealDraftItem>[];
      for (final food in analysis.foods) {
        try {
          drafts.add(await _resolver.resolve(food));
        } on Object catch (_) {
          drafts.add(_unresolvedDraft(food));
        }
      }
      emit(
        AiMealState(
          status: AiMealStatus.review,
          description: description,
          items: drafts,
          notes: analysis.notes,
        ),
      );
    } on AiApiException catch (error) {
      emit(
        AiMealState(
          status: AiMealStatus.failure,
          description: description,
          errorMessage: error.message,
          authenticationRequired: error.kind == AiApiFailureKind.authentication,
        ),
      );
    } on Object catch (_) {
      emit(
        AiMealState(
          status: AiMealStatus.failure,
          description: description,
          errorMessage:
              'Could not analyze this meal. Check your connection and try again.',
        ),
      );
    }
  }

  AiMealDraftItem _unresolvedDraft(AiExtractedFood food) => AiMealDraftItem(
    extractedFood: food,
    searchQuery: food.canonicalName,
    candidates: const [],
    selectedCandidateIndex: -1,
    amount: food.estimatedGrams,
  );

  void _changeAmount(AiMealAmountChanged event, Emitter<AiMealState> emit) {
    if (!_validIndex(event.index)) return;
    final items = [...state.items];
    items[event.index] = event.amount == null
        ? items[event.index].copyWith(clearAmount: true)
        : items[event.index].copyWith(amount: event.amount);
    emit(state.copyWith(items: items, clearError: true));
  }

  void _selectCandidate(
    AiMealCandidateSelected event,
    Emitter<AiMealState> emit,
  ) {
    if (!_validIndex(event.itemIndex)) return;
    final item = state.items[event.itemIndex];
    if (event.candidateIndex < 0 ||
        event.candidateIndex >= item.candidates.length) {
      return;
    }
    final items = [...state.items];
    items[event.itemIndex] = item.copyWith(
      selectedCandidateIndex: event.candidateIndex,
    );
    emit(state.copyWith(items: items, clearError: true));
  }

  void _removeItem(AiMealItemRemoved event, Emitter<AiMealState> emit) {
    if (!_validIndex(event.index)) return;
    final items = [...state.items]..removeAt(event.index);
    emit(state.copyWith(items: items, clearError: true));
  }

  Future<void> _resolveMatch(
    AiMealMatchRequested event,
    Emitter<AiMealState> emit,
  ) async {
    if (!_validIndex(event.index) || event.query.trim().length < 2) return;
    final before = state.items[event.index];
    final loadingItems = [...state.items];
    loadingItems[event.index] = before.copyWith(
      searchQuery: event.query.trim(),
      isResolving: true,
    );
    emit(state.copyWith(items: loadingItems, clearError: true));
    try {
      final resolved = await _resolver.resolve(
        before.extractedFood,
        query: event.query,
      );
      final currentIndex = state.items.indexWhere(
        (item) => item.extractedFood == before.extractedFood,
      );
      if (currentIndex < 0) return;
      final currentAmount = state.items[currentIndex].amount;
      final items = [...state.items];
      items[currentIndex] = resolved.copyWith(
        amount: currentAmount,
        clearAmount: currentAmount == null,
        isResolving: false,
      );
      emit(state.copyWith(items: items));
    } on Object catch (_) {
      final currentIndex = state.items.indexWhere(
        (item) => item.extractedFood == before.extractedFood,
      );
      if (currentIndex < 0) return;
      final items = [...state.items];
      items[currentIndex] = before.copyWith(
        searchQuery: event.query.trim(),
        candidates: const [],
        selectedCandidateIndex: -1,
        amount: state.items[currentIndex].amount,
        clearAmount: state.items[currentIndex].amount == null,
        isResolving: false,
      );
      emit(
        state.copyWith(
          items: items,
          errorMessage:
              'No trusted nutrition match was found for ${event.query.trim()}.',
        ),
      );
    }
  }

  Future<void> _save(
    SaveAiMealRequested event,
    Emitter<AiMealState> emit,
  ) async {
    if (!state.canSave) return;
    emit(state.copyWith(status: AiMealStatus.saving, clearError: true));
    try {
      await _saveMeal.save(
        items: state.items,
        intakeType: event.intakeType,
        day: event.day,
      );
      emit(state.copyWith(status: AiMealStatus.saved));
    } on Object catch (_) {
      emit(
        state.copyWith(
          status: AiMealStatus.review,
          errorMessage:
              'The meal could not be saved. Review the items and try again.',
        ),
      );
    }
  }

  Future<void> _saveToken(
    AiAccessTokenSubmitted event,
    Emitter<AiMealState> emit,
  ) async {
    final token = event.token.trim();
    if (token.isEmpty) return;
    await _tokenStore.save(token);
    if (state.description.isNotEmpty) {
      add(
        AnalyzeAiMealRequested(text: state.description, locale: event.locale),
      );
    } else {
      emit(state.copyWith(authenticationRequired: false, clearError: true));
    }
  }

  bool _validIndex(int index) => index >= 0 && index < state.items.length;
}
