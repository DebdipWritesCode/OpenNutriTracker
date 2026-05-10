part of 'custom_meals_bloc.dart';

abstract class CustomMealsEvent {}

class LoadCustomMealsEvent extends CustomMealsEvent {}

class DeleteCustomMealEvent extends CustomMealsEvent {
  final String mealKey;

  DeleteCustomMealEvent(this.mealKey);
}
