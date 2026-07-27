import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/ai_activity/data/ai_activity_api_client.dart';
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
  test(
    'sends authenticated workout text and parses exercise structure',
    () async {
      late http.Request captured;
      final client = AiActivityApiClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'exercises': [
                {
                  'original_text': 'dumbbell press 17.5kg 3x8',
                  'canonical_name': 'dumbbell press',
                  'sets': 3,
                  'reps_per_set': 8,
                  'load_value': 17.5,
                  'load_unit': 'kg',
                  'confidence': 0.97,
                  'requires_user_confirmation': false,
                },
              ],
              'stated_duration_minutes': null,
              'notes': [],
              'model_used': 'gpt-test',
            }),
            200,
          );
        }),
        tokenStore: _TokenStore('app-token'),
        baseUrl: 'https://api.example.test',
        delay: (_) async {},
      );

      final result = await client.analyzeActivity(
        text: 'dumbbell press 17.5kg 3x8',
        locale: 'en-IN',
      );

      expect(captured.url.path, '/api/v1/analyze/activity');
      expect(captured.headers['authorization'], 'Bearer app-token');
      expect(result.exercises.single.canonicalName, 'dumbbell press');
      expect(result.exercises.single.loadValue, 17.5);
      expect(jsonDecode(captured.body), {
        'text': 'dumbbell press 17.5kg 3x8',
        'locale': 'en-IN',
      });
    },
  );

  test('maps an unauthorized response to authentication failure', () {
    final client = AiActivityApiClient(
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
      () => client.analyzeActivity(text: 'shoulder press 3x8', locale: 'en'),
      throwsA(
        isA<AiApiException>().having(
          (error) => error.kind,
          'kind',
          AiApiFailureKind.authentication,
        ),
      ),
    );
  });

  test('retries a transient response and then succeeds', () async {
    var calls = 0;
    final client = AiActivityApiClient(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({
            'exercises': [],
            'stated_duration_minutes': 20,
            'notes': [],
            'model_used': 'gpt-test',
          }),
          200,
        );
      }),
      tokenStore: _TokenStore('token'),
      baseUrl: 'https://api.example.test',
      delay: (_) async {},
    );

    await client.analyzeActivity(text: 'presses for 20 minutes', locale: 'en');

    expect(calls, 2);
  });
}
