import 'dart:convert';

enum ActivityLogKind { aiStrength, treadmill }

enum TreadmillMode { walking, running }

enum TreadmillSpeedUnit { kilometersPerHour, milesPerHour }

class StrengthExerciseLog {
  final String name;
  final int sets;
  final int repsPerSet;
  final double? loadValue;
  final String? loadUnit;

  const StrengthExerciseLog({
    required this.name,
    required this.sets,
    required this.repsPerSet,
    this.loadValue,
    this.loadUnit,
  });

  factory StrengthExerciseLog.fromJson(Map<String, dynamic> json) =>
      StrengthExerciseLog(
        name: json['name'] as String,
        sets: (json['sets'] as num).toInt(),
        repsPerSet: (json['reps_per_set'] as num).toInt(),
        loadValue: (json['load_value'] as num?)?.toDouble(),
        loadUnit: json['load_unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'sets': sets,
    'reps_per_set': repsPerSet,
    'load_value': loadValue,
    'load_unit': loadUnit,
  };
}

class ActivityLogDetails {
  final ActivityLogKind kind;
  final int durationSeconds;
  final bool durationWasEstimated;
  final double profileWeightKg;
  final String estimationMethod;
  final List<StrengthExerciseLog> exercises;
  final TreadmillMode? treadmillMode;
  final double? speedKph;
  final double? inclinePercent;
  final TreadmillSpeedUnit? enteredSpeedUnit;
  final DateTime? loggedAt;

  const ActivityLogDetails({
    required this.kind,
    required this.durationSeconds,
    required this.durationWasEstimated,
    required this.profileWeightKg,
    required this.estimationMethod,
    this.exercises = const [],
    this.treadmillMode,
    this.speedKph,
    this.inclinePercent,
    this.enteredSpeedUnit,
    this.loggedAt,
  });

  int get totalSets =>
      exercises.fold<int>(0, (total, exercise) => total + exercise.sets);

  ActivityLogDetails copyWithDurationMinutes(
    double minutes, {
    double? profileWeightKg,
  }) => ActivityLogDetails(
    kind: kind,
    durationSeconds: (minutes * 60).round(),
    durationWasEstimated: false,
    profileWeightKg: profileWeightKg ?? this.profileWeightKg,
    estimationMethod: estimationMethod,
    exercises: exercises,
    treadmillMode: treadmillMode,
    speedKph: speedKph,
    inclinePercent: inclinePercent,
    enteredSpeedUnit: enteredSpeedUnit,
    loggedAt: loggedAt,
  );

  factory ActivityLogDetails.fromJson(Map<String, dynamic> json) =>
      ActivityLogDetails(
        kind: ActivityLogKind.values.byName(json['kind'] as String),
        durationSeconds: (json['duration_seconds'] as num).toInt(),
        durationWasEstimated: json['duration_was_estimated'] as bool? ?? false,
        profileWeightKg: (json['profile_weight_kg'] as num).toDouble(),
        estimationMethod: json['estimation_method'] as String,
        exercises: (json['exercises'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) =>
                  StrengthExerciseLog.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        treadmillMode: json['treadmill_mode'] == null
            ? null
            : TreadmillMode.values.byName(json['treadmill_mode'] as String),
        speedKph: (json['speed_kph'] as num?)?.toDouble(),
        inclinePercent: (json['incline_percent'] as num?)?.toDouble(),
        enteredSpeedUnit: json['entered_speed_unit'] == null
            ? null
            : TreadmillSpeedUnit.values.byName(
                json['entered_speed_unit'] as String,
              ),
        loggedAt: json['logged_at'] == null
            ? null
            : DateTime.tryParse(json['logged_at'] as String),
      );

  static ActivityLogDetails? tryParse(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return ActivityLogDetails.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  String encode() => jsonEncode({
    'kind': kind.name,
    'duration_seconds': durationSeconds,
    'duration_was_estimated': durationWasEstimated,
    'profile_weight_kg': profileWeightKg,
    'estimation_method': estimationMethod,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'treadmill_mode': treadmillMode?.name,
    'speed_kph': speedKph,
    'incline_percent': inclinePercent,
    'entered_speed_unit': enteredSpeedUnit?.name,
    'logged_at': loggedAt?.toIso8601String(),
  });
}
