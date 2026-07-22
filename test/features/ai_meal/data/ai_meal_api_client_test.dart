import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_api_client.dart';

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
