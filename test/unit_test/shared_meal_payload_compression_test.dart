import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/home/domain/entity/shared_meal_payload.dart';

void main() {
  MealEntity createMeal({
    required String code,
    required String name,
    String? brands,
    MealSourceEntity source = MealSourceEntity.custom,
    bool fullNutritionData = false,
  }) {
    return MealEntity(
      code: code,
      name: name,
      brands: brands,
      thumbnailImageUrl: fullNutritionData
          ? 'https://images.openfoodfacts.org/images/products/123/front.100.jpg'
          : null,
      mainImageUrl: fullNutritionData
          ? 'https://images.openfoodfacts.org/images/products/123/front.400.jpg'
          : null,
      url: null,
      mealQuantity: null,
      mealUnit: null,
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: fullNutritionData
          ? MealNutrimentsEntity(
              energyKcal100: 192.7,
              carbohydrates100: 22.0,
              fat100: 7.9,
              proteins100: 6.7,
              sugars100: 3.5,
              saturatedFat100: 2.6,
              fiber100: 2.0,
            )
          : MealNutrimentsEntity.empty(),
      source: source,
    );
  }

  IntakeEntity makeIntake(MealEntity meal, {int index = 0}) {
    return IntakeEntity(
      id: 'intake_$index',
      meal: meal,
      amount: 100 + index * 10.0,
      unit: 'g',
      dateTime: DateTime(2026, 4, 27),
      type: IntakeTypeEntity.breakfast,
    );
  }

  group('SharedMealPayload', () {
    // QR v40, error correction M: 3917 alphanumeric characters capacity
    const qrMaxChars = 3917;

    test('OFF items are encoded as 3-field barcode refs', () {
      final offMeal = createMeal(
        code: '4001724039143',
        name: 'Pizza Vegetale',
        brands: 'Dr. Oetker',
        source: MealSourceEntity.off,
        fullNutritionData: true,
      );
      final payload = SharedMealPayload.fromIntakeList([makeIntake(offMeal)]);

      expect(payload.offRefs.length, 1);
      expect(payload.items.length, 0);
      expect(payload.offRefs[0].barcode, '4001724039143');
      expect(payload.offRefs[0].amount, 100.0);
      expect(payload.offRefs[0].unit, 'g');
    });

    test('custom items are encoded as full-data arrays', () {
      final customMeal = createMeal(
        code: 'some-uuid',
        name: 'Homemade Soup',
        source: MealSourceEntity.custom,
        fullNutritionData: true,
      );
      final payload =
          SharedMealPayload.fromIntakeList([makeIntake(customMeal)]);

      expect(payload.offRefs.length, 0);
      expect(payload.items.length, 1);
      expect(payload.items[0].name, 'Homemade Soup');
    });

    test('round-trip preserves OFF refs and custom items', () {
      final intakes = [
        makeIntake(
          createMeal(
            code: '4001724039143',
            name: 'Pizza Vegetale',
            brands: 'Dr. Oetker',
            source: MealSourceEntity.off,
            fullNutritionData: true,
          ),
          index: 0,
        ),
        makeIntake(
          createMeal(
            code: 'some-uuid',
            name: 'Homemade Soup',
            source: MealSourceEntity.custom,
            fullNutritionData: true,
          ),
          index: 1,
        ),
      ];

      final encoded = SharedMealPayload.fromIntakeList(intakes).toJsonString();
      final decoded = SharedMealPayload.fromJsonString(encoded);

      expect(decoded.version, 1);
      expect(decoded.offRefs.length, 1);
      expect(decoded.offRefs[0].barcode, '4001724039143');
      expect(decoded.offRefs[0].amount, 100.0);
      expect(decoded.items.length, 1);
      expect(decoded.items[0].name, 'Homemade Soup');
      expect(decoded.items[0].energyKcal100, 192.7);
    });

    test('payloads for typical meal counts fit within QR v40/M capacity', () {
      // 5 OFF items: only barcodes stored — very small
      final offIntakes = List.generate(
        5,
        (i) => makeIntake(
          createMeal(
              code: '400172403914$i',
              name: 'Product $i',
              source: MealSourceEntity.off),
          index: i,
        ),
      );
      expect(
        SharedMealPayload.fromIntakeList(offIntakes).toJsonString().length,
        lessThan(qrMaxChars),
      );

      // 10 custom items with full nutritional data — worst case
      final customIntakes = List.generate(
        10,
        (i) => makeIntake(
          createMeal(
            code: 'uuid-$i',
            name: 'Meal Item $i',
            brands: 'Brand $i',
            source: MealSourceEntity.custom,
            fullNutritionData: true,
          ),
          index: i,
        ),
      );
      expect(
        SharedMealPayload.fromIntakeList(customIntakes).toJsonString().length,
        lessThan(qrMaxChars),
      );
    });

    test('unsupported version throws SharedMealParseException', () {
      final raw = base64Url.encode(gzip.encode(utf8.encode('[99,[],[]]')));
      expect(
        () => SharedMealPayload.fromJsonString(raw),
        throwsA(isA<SharedMealParseException>()),
      );
    });

    test('plain JSON (uncompressed) input is also accepted', () {
      // The encoder always gzips, but the decoder should fall back to
      // treating the input as a plain JSON string when gzip/base64 fails.
      const raw = '[1,[],[]]';
      final decoded = SharedMealPayload.fromJsonString(raw);
      expect(decoded.version, equals(1));
      expect(decoded.offRefs, isEmpty);
      expect(decoded.items, isEmpty);
    });

    test('malformed top-level shape throws SharedMealParseException', () {
      final raw = base64Url.encode(gzip.encode(utf8.encode('{"bad":true}')));
      expect(
        () => SharedMealPayload.fromJsonString(raw),
        throwsA(isA<SharedMealParseException>()),
      );
    });

    test('completely garbage input throws SharedMealParseException', () {
      expect(
        () => SharedMealPayload.fromJsonString('not-base64-or-json'),
        throwsA(isA<SharedMealParseException>()),
      );
    });

    test('totalCount sums OFF refs and custom items', () {
      final intakes = [
        makeIntake(createMeal(
            code: '4001', name: 'A', source: MealSourceEntity.off)),
        makeIntake(createMeal(
            code: '4002', name: 'B', source: MealSourceEntity.off)),
        makeIntake(
            createMeal(
                code: 'cust-1',
                name: 'Custom',
                source: MealSourceEntity.custom)),
      ];
      final payload = SharedMealPayload.fromIntakeList(intakes);
      expect(payload.totalCount, equals(3));
      expect(payload.offRefs.length, equals(2));
      expect(payload.items.length, equals(1));
    });

    test('OFF intake without a barcode falls back to a custom item', () {
      // A meal flagged source=off but missing its code shouldn't be lost —
      // it must be encoded as a full custom item so the recipient can still
      // see its data.
      final orphan = createMeal(
          code: '', name: 'Lost Product', source: MealSourceEntity.off);
      // Override code to null via a fresh entity — our helper requires a code,
      // so build a minimal stand-in.
      final intake = IntakeEntity(
        id: 'orphan',
        meal: MealEntity(
          code: null,
          name: orphan.name,
          brands: null,
          thumbnailImageUrl: null,
          mainImageUrl: null,
          url: null,
          mealQuantity: null,
          mealUnit: null,
          servingQuantity: null,
          servingUnit: null,
          servingSize: null,
          nutriments: MealNutrimentsEntity.empty(),
          source: MealSourceEntity.off,
        ),
        amount: 100,
        unit: 'g',
        dateTime: DateTime(2026, 4, 27),
        type: IntakeTypeEntity.breakfast,
      );

      final payload = SharedMealPayload.fromIntakeList([intake]);
      expect(payload.offRefs, isEmpty);
      expect(payload.items.length, equals(1));
      expect(payload.items.single.name, equals('Lost Product'));
    });

    test('toMealEntities assigns a fresh unique code to each rebuilt item',
        () {
      final intakes = [
        makeIntake(createMeal(
            code: 'c1', name: 'A', source: MealSourceEntity.custom)),
        makeIntake(createMeal(
            code: 'c2', name: 'B', source: MealSourceEntity.custom)),
      ];
      final payload = SharedMealPayload.fromIntakeList(intakes);
      final rebuilt = payload.toMealEntities();
      expect(rebuilt.length, equals(2));
      expect(rebuilt[0].code, isNot(equals(rebuilt[1].code)));
      expect(rebuilt[0].code, isNotNull);
    });

    test('whole-number nutrient values round-trip as ints in the JSON', () {
      // The _compact() optimisation emits ints for whole numbers. Verify the
      // round-trip restores the original value as a double.
      final meal = createMeal(
        code: 'whole',
        name: 'Round',
        source: MealSourceEntity.custom,
      );
      final intake = IntakeEntity(
        id: 'r',
        meal: MealEntity(
          code: meal.code,
          name: meal.name,
          brands: null,
          thumbnailImageUrl: null,
          mainImageUrl: null,
          url: null,
          mealQuantity: null,
          mealUnit: null,
          servingQuantity: null,
          servingUnit: null,
          servingSize: null,
          nutriments: MealNutrimentsEntity(
            energyKcal100: 100, // whole
            carbohydrates100: 22.5, // 1dp
            fat100: 0,
            proteins100: 7,
            sugars100: null,
            saturatedFat100: null,
            fiber100: null,
          ),
          source: MealSourceEntity.custom,
        ),
        amount: 100,
        unit: 'g',
        dateTime: DateTime(2026, 4, 27),
        type: IntakeTypeEntity.breakfast,
      );
      final encoded =
          SharedMealPayload.fromIntakeList([intake]).toJsonString();
      final decoded = SharedMealPayload.fromJsonString(encoded);

      expect(decoded.items.single.energyKcal100, equals(100));
      expect(decoded.items.single.carbohydrates100, equals(22.5));
      expect(decoded.items.single.fat100, equals(0));
      expect(decoded.items.single.proteins100, equals(7));
    });
  });
}
