part of 'trends_bloc.dart';

abstract class TrendsState extends Equatable {
  const TrendsState();

  @override
  List<Object?> get props => [];
}

class TrendsInitial extends TrendsState {
  const TrendsInitial();
}

class TrendsLoading extends TrendsState {
  const TrendsLoading();
}

class TrendsLoaded extends TrendsState {
  final int rangeDays;
  final List<TrackedDayEntity> days; // tracked days over the selected window
  final List<TrackedDayEntity> priorWeek; // the 7 days before this week
  final List<WeightLogEntity> weight; // full weight history, windowed in the UI
  final bool usesImperialUnits;
  final double? targetWeightKg; // user's #119 target, for the chart reference

  const TrendsLoaded({
    required this.rangeDays,
    required this.days,
    required this.priorWeek,
    required this.weight,
    required this.usesImperialUnits,
    required this.targetWeightKg,
  });

  @override
  List<Object?> get props =>
      [rangeDays, days, priorWeek, weight, usesImperialUnits, targetWeightKg];
}

class TrendsFailed extends TrendsState {
  final String message;

  const TrendsFailed(this.message);

  @override
  List<Object?> get props => [message];
}
