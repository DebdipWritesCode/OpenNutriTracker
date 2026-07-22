import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:opennutritracker/features/ai_meal/data/ai_access_token_store.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';

abstract interface class AiMealGateway {
  Future<AiMealAnalysis> analyzeMeal({
    required String text,
    required String locale,
  });
}

enum AiApiFailureKind {
  authentication,
  rateLimited,
  validation,
  unavailable,
  network,
  invalidResponse,
}

class AiApiException implements Exception {
  final AiApiFailureKind kind;
  final String message;
  final Duration? retryAfter;

  const AiApiException(this.kind, this.message, {this.retryAfter});

  @override
  String toString() => message;
}

class AiMealApiClient implements AiMealGateway {
  final http.Client _client;
  final AiAccessTokenStore _tokenStore;
  final Uri _endpoint;
  final Duration timeout;
  final int maxAttempts;
  final Future<void> Function(Duration) _delay;

  AiMealApiClient({
    required http.Client client,
    required AiAccessTokenStore tokenStore,
    required String baseUrl,
    this.timeout = const Duration(seconds: 65),
    this.maxAttempts = 3,
    Future<void> Function(Duration)? delay,
  }) : _client = client,
       _tokenStore = tokenStore,
       _endpoint = Uri.parse(baseUrl).resolve('/api/v1/analyze/text'),
       _delay = delay ?? Future<void>.delayed;

  @override
  Future<AiMealAnalysis> analyzeMeal({
    required String text,
    required String locale,
  }) async {
    final token = await _tokenStore.read();
    AiApiException? lastFailure;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client
            .post(
              _endpoint,
              headers: {
                HttpHeaders.contentTypeHeader: 'application/json',
                HttpHeaders.acceptHeader: 'application/json',
                if (token != null && token.isNotEmpty)
                  HttpHeaders.authorizationHeader: 'Bearer $token',
              },
              body: jsonEncode({'text': text.trim(), 'locale': locale}),
            )
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            return AiMealAnalysis.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>,
            );
          } on Object catch (_) {
            throw const AiApiException(
              AiApiFailureKind.invalidResponse,
              'The AI service returned an unreadable response.',
            );
          }
        }

        final failure = _failureFromResponse(response);
        lastFailure = failure;
        if (!_isRetryable(failure) || attempt == maxAttempts) throw failure;
        await _delay(
          failure.retryAfter ?? Duration(milliseconds: 400 * attempt),
        );
        continue;
      } on AiApiException {
        rethrow;
      } on TimeoutException {
        lastFailure = const AiApiException(
          AiApiFailureKind.network,
          'The AI service took too long to respond.',
        );
      } on SocketException {
        lastFailure = const AiApiException(
          AiApiFailureKind.network,
          'No connection to the AI service. Check your internet connection.',
        );
      } on http.ClientException {
        lastFailure = const AiApiException(
          AiApiFailureKind.network,
          'Could not connect to the AI service.',
        );
      }

      if (attempt < maxAttempts) {
        await _delay(Duration(milliseconds: 400 * attempt));
      }
    }
    throw lastFailure ??
        const AiApiException(
          AiApiFailureKind.unavailable,
          'The AI service is temporarily unavailable.',
        );
  }

  AiApiException _failureFromResponse(http.Response response) {
    String? serverMessage;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      serverMessage = error?['message'] as String?;
    } on Object catch (_) {
      serverMessage = null;
    }

    switch (response.statusCode) {
      case 401:
      case 403:
        return AiApiException(
          AiApiFailureKind.authentication,
          serverMessage ?? 'The AI access token is missing or invalid.',
        );
      case 422:
        return const AiApiException(
          AiApiFailureKind.validation,
          'Describe at least one food or drink and try again.',
        );
      case 429:
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        return AiApiException(
          AiApiFailureKind.rateLimited,
          serverMessage ?? 'Too many requests. Please wait and try again.',
          retryAfter: seconds == null ? null : Duration(seconds: seconds),
        );
      default:
        return AiApiException(
          AiApiFailureKind.unavailable,
          serverMessage ?? 'The AI service is temporarily unavailable.',
        );
    }
  }

  bool _isRetryable(AiApiException failure) =>
      failure.kind == AiApiFailureKind.rateLimited ||
      failure.kind == AiApiFailureKind.unavailable ||
      failure.kind == AiApiFailureKind.network;
}
