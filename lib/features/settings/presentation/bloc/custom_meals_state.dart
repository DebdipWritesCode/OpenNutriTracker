part of 'custom_meals_bloc.dart';

abstract class CustomMealsState {}

class CustomMealsInitial extends CustomMealsState {}

class CustomMealsLoadingState extends CustomMealsState {}

class CustomMealsLoadedState extends CustomMealsState {
  final List<MealEntity> meals;

  CustomMealsLoadedState({required this.meals});
}

class CustomMealsFailedState extends CustomMealsState {}
