import 'package:opennutritracker/core/utils/env.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

abstract interface class AiAccessTokenStore {
  Future<String?> read();
  Future<void> save(String token);
  Future<void> clear();
}

class SecureAiAccessTokenStore implements AiAccessTokenStore {
  final SecureAppStorageProvider _storage;

  SecureAiAccessTokenStore(this._storage);

  @override
  Future<String?> read() async {
    final stored = (await _storage.getAiAccessToken())?.trim();
    if (stored != null && stored.isNotEmpty) return stored;

    // Optional bootstrap for private/test builds. Once copied, subsequent
    // reads come only from encrypted platform storage.
    final bundled = Env.aiAccessToken.trim();
    if (bundled.isEmpty) return null;
    await _storage.setAiAccessToken(bundled);
    return bundled;
  }

  @override
  Future<void> save(String token) => _storage.setAiAccessToken(token);

  @override
  Future<void> clear() => _storage.clearAiAccessToken();
}
