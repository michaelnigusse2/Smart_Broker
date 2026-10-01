import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ai_provider.dart';

/// Stores one API key per AI provider in secure storage.
class ApiKeyService {
  static const _legacyNvidiaKey = 'nvidia_api_key';
  final _storage = const FlutterSecureStorage();

  static final ApiKeyService _instance = ApiKeyService._internal();
  factory ApiKeyService() => _instance;
  ApiKeyService._internal();

  String _keyFor(AiProvider provider) => 'ai_key_${provider.id}';

  Future<String?> getKey(AiProvider provider) async {
    final key = await _storage.read(key: _keyFor(provider));
    if (key != null || provider.id != AiProvider.nvidia.id) return key;
    // Keys saved before multi-provider support were stored under this name.
    return _storage.read(key: _legacyNvidiaKey);
  }

  Future<void> saveKey(AiProvider provider, String key) async {
    await _storage.write(key: _keyFor(provider), value: key.trim());
  }

  Future<void> deleteKey(AiProvider provider) async {
    await _storage.delete(key: _keyFor(provider));
    if (provider.id == AiProvider.nvidia.id) {
      await _storage.delete(key: _legacyNvidiaKey);
    }
  }
}
