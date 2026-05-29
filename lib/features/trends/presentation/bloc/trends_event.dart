part of 'trends_bloc.dart';

abstract class TrendsEvent extends Equatable {
  const TrendsEvent();

  @override
  List<Object?> get props => [];
}

class LoadTrendsEvent extends TrendsEvent {
  const LoadTrendsEvent();
}
