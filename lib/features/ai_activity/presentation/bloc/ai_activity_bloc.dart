import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_estimated_activity_usecase.dart';
import 'package:opennutritracker/features/ai_activity/data/ai_activity_api_client.dart';
import 'package:opennutritracker/features/ai_activity/data/dto/ai_activity_analysis_dto.dart';
import 'package:opennutritracker/features/ai_activity/domain/activity_duration_estimator.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';
import 'package:opennutritracker/features/ai_reuse/domain/recent_ai_log.dart';

enum AiActivityStatus { initial, analyzing, review, saving, saved, failure }

sealed class AiActivityEvent extends Equatable {
  const AiActivityEvent();

  @override
  List<Object?> get props => [];
}

class AnalyzeAiActivityRequested extends AiActivityEvent {
  final String text;
  final String locale;

  const AnalyzeAiActivityRequested(this.text, this.locale);

  @override
  List<Object?> get props => [text, locale];
}

class AiActivityExerciseChanged extends AiActivityEvent {
  final int index;
  final AiExtractedExercise exercise;

  const AiActivityExerciseChanged(this.index, this.exercise);

  @override
  List<Object?> get props => [index, exercise];
}

class AiActivityExerciseRemoved extends AiActivityEvent {
  final int index;

  const AiActivityExerciseRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

class AiActivityExerciseAdded extends AiActivityEvent {
  const AiActivityExerciseAdded();
}

class AiActivityDurationChanged extends AiActivityEvent {
  final double? minutes;

  const AiActivityDurationChanged(this.minutes);

  @override
  List<Object?> get props => [minutes];
}

class SaveAiActivityRequested extends AiActivityEvent {
  final DateTime day;
  final String activityName;

  const SaveAiActivityRequested(this.day, this.activityName);

  @override
  List<Object?> get props => [day, activityName];
}

class UseRecentAiWorkoutRequested extends AiActivityEvent {
  final RecentAiWorkoutLog log;

  const UseRecentAiWorkoutRequested(this.log);

  @override
  List<Object?> get props => [log];
}

class AiActivityAccessTokenSubmitted extends AiActivityEvent {
  final String token;
  final String locale;

  const AiActivityAccessTokenSubmitted(this.token, this.locale);

  @override
  List<Object?> get props => [token, locale];
}

class AiActivityState extends Equatable {
  static const resistanceTrainingMet = 3.5;

  final AiActivityStatus status;
  final String description;
  final List<AiExtractedExercise> exercises;
  final double? durationMinutes;
  final bool durationWasEstimated;
  final double? profileWeightKg;
  final List<String> notes;
  final String? errorMessage;
  final bool authenticationRequired;

  const AiActivityState({
    this.status = AiActivityStatus.initial,
    this.description = '',
    this.exercises = const [],
    this.durationMinutes,
    this.durationWasEstimated = false,
    this.profileWeightKg,
    this.notes = const [],
    this.errorMessage,
    this.authenticationRequired = false,
  });

  double? get estimatedCalories {
    final duration = durationMinutes;
    final weight = profileWeightKg;
    if (duration == null || duration <= 0 || weight == null || weight <= 0) {
      return null;
    }
    return resistanceTrainingMet * weight * duration / 60;
  }

  bool get canSave =>
      status == AiActivityStatus.review &&
      durationMinutes != null &&
      durationMinutes! > 0 &&
      estimatedCalories != null &&
      exercises.isNotEmpty &&
      exercises.every(
        (exercise) =>
            exercise.canonicalName.trim().isNotEmpty &&
            exercise.sets != null &&
            exercise.sets! > 0 &&
            exercise.repsPerSet != null &&
            exercise.repsPerSet! > 0,
      );

  AiActivityState copyWith({
    AiActivityStatus? status,
    String? description,
    List<AiExtractedExercise>? exercises,
    double? durationMinutes,
    bool clearDuration = false,
    bool? durationWasEstimated,
    double? profileWeightKg,
    List<String>? notes,
    String? errorMessage,
    bool clearError = false,
    bool? authenticationRequired,
  }) => AiActivityState(
    status: status ?? this.status,
    description: description ?? this.description,
    exercises: exercises ?? this.exercises,
    durationMinutes: clearDuration
        ? null
        : (durationMinutes ?? this.durationMinutes),
    durationWasEstimated: durationWasEstimated ?? this.durationWasEstimated,
    profileWeightKg: profileWeightKg ?? this.profileWeightKg,
    notes: notes ?? this.notes,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    authenticationRequired:
        authenticationRequired ?? this.authenticationRequired,
  );

  @override
  List<Object?> get props => [
    status,
    description,
    exercises,
    durationMinutes,
    durationWasEstimated,
    profileWeightKg,
    notes,
    errorMessage,
    authenticationRequired,
  ];
}

class AiActivityBloc extends Bloc<AiActivityEvent, AiActivityState> {
  final AiActivityGateway _gateway;
  final GetUserUsecase _getUser;
  final SaveEstimatedActivityUsecase _saveActivity;
  final AiAccessTokenStore _tokenStore;

  AiActivityBloc(
    this._gateway,
    this._getUser,
    this._saveActivity,
    this._tokenStore,
  ) : super(const AiActivityState()) {
    on<AnalyzeAiActivityRequested>(_analyze);
    on<AiActivityExerciseChanged>(_changeExercise);
    on<AiActivityExerciseRemoved>(_removeExercise);
    on<AiActivityExerciseAdded>(_addExercise);
    on<AiActivityDurationChanged>(_changeDuration);
    on<UseRecentAiWorkoutRequested>(_useRecentWorkout);
    on<SaveAiActivityRequested>(_save);
    on<AiActivityAccessTokenSubmitted>(_saveToken);
  }

  Future<void> _useRecentWorkout(
    UseRecentAiWorkoutRequested event,
    Emitter<AiActivityState> emit,
  ) async {
    try {
      final user = await _getUser.getUserData();
      final details = event.log.details;
      emit(
        AiActivityState(
          status: AiActivityStatus.review,
          description: details.exercises
              .map((exercise) => exercise.name)
              .join(', '),
          exercises: details.exercises
              .map(
                (exercise) => AiExtractedExercise(
                  originalText: exercise.name,
                  canonicalName: exercise.name,
                  sets: exercise.sets,
                  repsPerSet: exercise.repsPerSet,
                  loadValue: exercise.loadValue,
                  loadUnit: exercise.loadUnit,
                  confidence: 1,
                  requiresUserConfirmation: false,
                ),
              )
              .toList(growable: false),
          durationMinutes: details.durationSeconds / 60,
          durationWasEstimated: false,
          profileWeightKg: user.weightKG,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          status: AiActivityStatus.failure,
          errorMessage:
              'Could not load this recent workout. Check your profile and try again.',
        ),
      );
    }
  }

  Future<void> _analyze(
    AnalyzeAiActivityRequested event,
    Emitter<AiActivityState> emit,
  ) async {
    final description = event.text.trim();
    if (description.length < 2) {
      emit(
        state.copyWith(
          status: AiActivityStatus.failure,
          errorMessage: 'Describe at least one strength exercise.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AiActivityStatus.analyzing,
        description: description,
        clearError: true,
        authenticationRequired: false,
      ),
    );
    try {
      final results = await Future.wait<Object>([
        _gateway.analyzeActivity(text: description, locale: event.locale),
        _getUser.getUserData(),
      ]);
      final analysis = results[0] as AiActivityAnalysis;
      final user = results[1] as UserEntity;
      final localEstimate = ActivityDurationEstimator.estimate(
        analysis.exercises,
      );
      final statedDuration = analysis.statedDurationMinutes;
      emit(
        state.copyWith(
          status: AiActivityStatus.review,
          exercises: analysis.exercises,
          durationMinutes: statedDuration ?? localEstimate.minutes,
          durationWasEstimated: statedDuration == null,
          profileWeightKg: user.weightKG,
          notes: [
            ...analysis.notes,
            if (statedDuration == null && localEstimate.usedFallback)
              'Some set or rep counts were missing, so the workout time needs review.',
          ],
          clearError: true,
          authenticationRequired: false,
        ),
      );
    } on AiApiException catch (error) {
      emit(
        state.copyWith(
          status: AiActivityStatus.failure,
          errorMessage: error.message,
          authenticationRequired: error.kind == AiApiFailureKind.authentication,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          status: AiActivityStatus.failure,
          errorMessage: 'Could not prepare this workout. Please try again.',
        ),
      );
    }
  }

  void _changeExercise(
    AiActivityExerciseChanged event,
    Emitter<AiActivityState> emit,
  ) {
    if (state.status != AiActivityStatus.review ||
        event.index < 0 ||
        event.index >= state.exercises.length) {
      return;
    }
    final exercises = [...state.exercises];
    exercises[event.index] = event.exercise;
    emit(state.copyWith(exercises: exercises, clearError: true));
  }

  void _removeExercise(
    AiActivityExerciseRemoved event,
    Emitter<AiActivityState> emit,
  ) {
    if (state.status != AiActivityStatus.review ||
        event.index < 0 ||
        event.index >= state.exercises.length) {
      return;
    }
    final exercises = [...state.exercises]..removeAt(event.index);
    emit(state.copyWith(exercises: exercises, clearError: true));
  }

  void _addExercise(
    AiActivityExerciseAdded event,
    Emitter<AiActivityState> emit,
  ) {
    if (state.status != AiActivityStatus.review) return;
    emit(
      state.copyWith(
        exercises: [
          ...state.exercises,
          const AiExtractedExercise(
            originalText: '',
            canonicalName: '',
            sets: null,
            repsPerSet: null,
            loadValue: null,
            loadUnit: null,
            confidence: 1,
            requiresUserConfirmation: true,
          ),
        ],
        clearError: true,
      ),
    );
  }

  void _changeDuration(
    AiActivityDurationChanged event,
    Emitter<AiActivityState> emit,
  ) {
    if (state.status != AiActivityStatus.review) return;
    emit(
      state.copyWith(
        durationMinutes: event.minutes,
        clearDuration: event.minutes == null,
        durationWasEstimated: false,
        clearError: true,
      ),
    );
  }

  Future<void> _save(
    SaveAiActivityRequested event,
    Emitter<AiActivityState> emit,
  ) async {
    if (!state.canSave) return;
    emit(state.copyWith(status: AiActivityStatus.saving, clearError: true));
    try {
      final details = ActivityLogDetails(
        kind: ActivityLogKind.aiStrength,
        durationSeconds: (state.durationMinutes! * 60).round(),
        durationWasEstimated: state.durationWasEstimated,
        profileWeightKg: state.profileWeightKg!,
        estimationMethod: '2024-adult-compendium-02054',
        loggedAt: DateTime.now(),
        exercises: state.exercises
            .map(
              (exercise) => StrengthExerciseLog(
                name: exercise.canonicalName,
                sets: exercise.sets!,
                repsPerSet: exercise.repsPerSet!,
                loadValue: exercise.loadValue,
                loadUnit: exercise.loadUnit,
              ),
            )
            .toList(growable: false),
      );
      await _saveActivity.save(
        day: event.day,
        activity: PhysicalActivityEntity.aiStrength(event.activityName),
        durationMinutes: state.durationMinutes!,
        burnedKcal: state.estimatedCalories!,
        detailsJson: details.encode(),
      );
      emit(state.copyWith(status: AiActivityStatus.saved, clearError: true));
    } on Object {
      emit(
        state.copyWith(
          status: AiActivityStatus.review,
          errorMessage: 'The workout could not be saved. Please try again.',
        ),
      );
    }
  }

  Future<void> _saveToken(
    AiActivityAccessTokenSubmitted event,
    Emitter<AiActivityState> emit,
  ) async {
    final token = event.token.trim();
    if (token.isEmpty) return;
    await _tokenStore.save(token);
    add(AnalyzeAiActivityRequested(state.description, event.locale));
  }
}
