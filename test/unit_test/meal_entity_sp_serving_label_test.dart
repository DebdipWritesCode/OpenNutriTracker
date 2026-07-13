import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_food_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

SpFoodDTO _food({
  double? servingQuantity,
  String? servingUnit,
  String? servingSize,
  double? servingGramWeight,
}) {
  return SpFoodDTO(
    foodId: 1,
    source: 'fdc_foundation',
    sourceCode: '1000',
    name: 'Test food',
    servingQuantity: servingQuantity,
    servingUnit: servingUnit,
    servingSize: servingSize,
    servingGramWeight: servingGramWeight,
  );
}

void main() {
  group('MealEntity.fromSpFood serving label', () {
    test('count-based unit appends the portion weight in grams', () {
      final meal = MealEntity.fromSpFood(_food(
        servingQuantity: 1,
        servingUnit: 'portion',
        servingGramWeight: 150,
      ));
      expect(meal.servingSize, '1 portion (150 g)');
    });

    test(
        "FDC's raw 'undetermined' unit is presented as portion with weight "
        '(pre-view-refresh backends and cached rows)', () {
      final meal = MealEntity.fromSpFood(_food(
        servingQuantity: 2,
        servingUnit: 'undetermined',
        servingGramWeight: 85.5,
      ));
      expect(meal.servingSize, '2 portion (85.5 g)');
    });

    test('weight units are not doubled up with a gram suffix', () {
      final meal = MealEntity.fromSpFood(_food(
        servingQuantity: 100,
        servingUnit: 'g',
        servingGramWeight: 100,
      ));
      expect(meal.servingSize, '100 g');
    });

    test(
        'a portion description from the backend gets the weight appended, '
        'FDC-website style', () {
      final meal = MealEntity.fromSpFood(_food(
        servingSize: '1 cup, sliced',
        servingQuantity: 1,
        servingUnit: 'cup',
        servingGramWeight: 240,
      ));
      expect(meal.servingSize, '1 cup, sliced (240 g)');
    });

    test('a description already stating a weight is not doubled up', () {
      final meal = MealEntity.fromSpFood(_food(
        servingSize: '38 g',
        servingGramWeight: 38,
      ));
      expect(meal.servingSize, '38 g');
    });

    test('gram weight alone still yields a label', () {
      final meal = MealEntity.fromSpFood(_food(servingGramWeight: 30));
      expect(meal.servingSize, '30 g');
    });
  });
}
