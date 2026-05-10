part of 'products_bloc.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();
}

class ProductsInitial extends ProductsState {
  @override
  List<Object> get props => [];
}

class ProductsLoadingState extends ProductsState {
  @override
  List<Object?> get props => [];
}

class ProductsLoadedState extends ProductsState {
  final List<MealEntity> products;
  final bool usesImperialUnits;

  /// True when the remote OFF source returned zero results (or failed
  /// silently — e.g. rate limit). The UI uses this to show a "no results"
  /// hint below any custom-meal matches.
  final bool remoteSourceEmpty;

  const ProductsLoadedState({
    required this.products,
    this.usesImperialUnits = false,
    this.remoteSourceEmpty = false,
  });

  @override
  List<Object?> get props => [products, remoteSourceEmpty];
}

class ProductsFailedState extends ProductsState {
  @override
  List<Object?> get props => [];
}
