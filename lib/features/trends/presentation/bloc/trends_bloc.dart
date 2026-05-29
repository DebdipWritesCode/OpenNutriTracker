import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';

part 'trends_event.dart';
part 'trends_state.dart';

class TrendsBloc extends Bloc<TrendsEvent, TrendsState> {
  final GetTrackedDayUsecase _getTrackedDayUsecase;
  final GetWeightLogUsecase _getWeightLogUsecase;

  TrendsBloc(this._getTrackedDayUsecase, this._getWeightLogUsecase)
      : super(const TrendsInitial()) {
    on<LoadTrendsEvent>((event, emit) async {
      emit(const TrendsLoading());
      try {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final week = await _getTrackedDayUsecase.getTrackedDaysByRange(
          today.subtract(const Duration(days: 6)),
          today,
        );
        final weight = await _getWeightLogUsecase.getEntriesInRange(
          today.subtract(const Duration(days: 29)),
          today,
        );
        weight.sort((a, b) => a.date.compareTo(b.date));
        emit(TrendsLoaded(week: week, weight: weight));
      } catch (e) {
        emit(TrendsFailed(e.toString()));
      }
    });
  }
}
