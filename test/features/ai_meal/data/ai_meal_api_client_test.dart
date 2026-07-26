import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_photo.dart';

class _TokenStore implements AiAccessTokenStore {
  String? token;

  _TokenStore(this.token);

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String token) async => this.token = token;
}

void main() {
  test('parses structured foods and sends the bearer token', () async {
    late http.Request captured;
    final client = AiMealApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'foods': [
              {
                'original_text': '150g curd',
                'canonical_name': 'curd',
                'quantity': 150,
                'unit': 'g',
                'estimated_grams': 150,
                'preparation': null,
                'confidence': 0.98,
                'requires_user_confirmation': false,
              },
            ],
            'notes': [],
            'model_used': 'gpt-test',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      tokenStore: _TokenStore('app-token'),
      baseUrl: 'https://api.example.test',
      delay: (_) async {},
    );

    final result = await client.analyzeMeal(text: '150g curd', locale: 'en-IN');

    expect(captured.url.path, '/api/v1/analyze/text');
    expect(captured.headers['authorization'], 'Bearer app-token');
    expect(result.foods.single.canonicalName, 'curd');
    expect(result.foods.single.estimatedGrams, 150);
  });

  test('maps an unauthorized response to authentication failure', () async {
    final client = AiMealApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'A Bearer access token is required'},
          }),
          401,
        ),
      ),
      tokenStore: _TokenStore(null),
      baseUrl: 'https://api.example.test',
      maxAttempts: 1,
      delay: (_) async {},
    );

    expect(
      () => client.analyzeMeal(text: 'rice', locale: 'en'),
      throwsA(
        isA<AiApiException>().having(
          (error) => error.kind,
          'kind',
          AiApiFailureKind.authentication,
        ),
      ),
    );
  });

  test('sends a compressed photo to the image analysis endpoint', () async {
    late http.Request captured;
    final client = AiMealApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'foods': [], 'notes': [], 'model_used': 'gpt-test'}),
          200,
        );
      }),
      tokenStore: _TokenStore('app-token'),
      baseUrl: 'https://api.example.test',
      delay: (_) async {},
    );

    await client.analyzePhoto(
      photo: AiMealPhoto(
        path: '/tmp/meal.jpg',
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
        mimeType: 'image/jpeg',
        fileName: 'meal-photo.jpg',
      ),
      locale: 'en-IN',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.url.path, '/api/v1/analyze/image');
    expect(captured.headers['authorization'], 'Bearer app-token');
    expect(body['mime_type'], 'image/jpeg');
    expect(body['locale'], 'en-IN');
    expect(base64Decode(body['image_base64'] as String), [
      0xff,
      0xd8,
      0xff,
      0xe0,
    ]);
  });

  test('re-sends photo, current draft, and history for a correction', () async {
    late http.Request captured;
    final client = AiMealApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'foods': [
              {
                'original_text': '180g paneer curry',
                'canonical_name': 'paneer curry',
                'quantity': 180,
                'unit': 'g',
                'estimated_grams': 180,
                'preparation': null,
                'confidence': 0.96,
                'requires_user_confirmation': false,
              },
            ],
            'notes': [],
            'assistant_message':
                'Changed the dish to paneer curry and set it to 180 g.',
            'model_used': 'gpt-test',
          }),
          200,
        );
      }),
      tokenStore: _TokenStore('app-token'),
      baseUrl: 'https://api.example.test',
      delay: (_) async {},
    );
    final photo = AiMealPhoto(
      path: '/tmp/meal.jpg',
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
      mimeType: 'image/jpeg',
      fileName: 'meal-photo.jpg',
    );
    const currentFood = AiExtractedFood(
      originalText: 'mixed vegetable dish',
      canonicalName: 'mixed cooked vegetable dish',
      quantity: 1,
      unit: 'bowl',
      estimatedGrams: 120,
      preparation: null,
      confidence: 0.55,
      requiresUserConfirmation: true,
    );

    final result = await client.refinePhoto(
      photo: photo,
      currentFoods: const [currentFood],
      correctionHistory: const [
        AiMealCorrectionTurn(
          instruction: 'There was one bowl.',
          assistantMessage: 'Kept one bowl in the draft.',
        ),
      ],
      correction: 'That is paneer curry, not mixed vegetables.',
      locale: 'en-IN',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.url.path, '/api/v1/analyze/image/refine');
    expect(body['correction'], 'That is paneer curry, not mixed vegetables.');
    expect(
      (body['current_foods'] as List<dynamic>).single,
      containsPair('estimated_grams', 120),
    );
    expect(
      (body['correction_history'] as List<dynamic>).single,
      containsPair('instruction', 'There was one bowl.'),
    );
    expect(result.foods.single.canonicalName, 'paneer curry');
    expect(result.assistantMessage, contains('180 g'));
  });

  test('retries a transient server error and then succeeds', () async {
    var calls = 0;
    final client = AiMealApiClient(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({'foods': [], 'notes': [], 'model_used': 'test'}),
          200,
        );
      }),
      tokenStore: _TokenStore('token'),
      baseUrl: 'https://api.example.test',
      delay: (_) async {},
    );

    await client.analyzeMeal(text: 'rice', locale: 'en');

    expect(calls, 2);
  });
}
