import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyService {
  static const _key = 'nvidia_api_key';
  final _storage = const FlutterSecureStorage();

  static final ApiKeyService _instance = ApiKeyService._internal();

  factory ApiKeyService() {
    return _instance;
  }

  ApiKeyService._internal();

  Future<String?> getKey() async {
    return await _storage.read(key: _key);
  }

  Future<void> saveKey(String key) async {
    await _storage.write(key: _key, value: key.trim());
  }

  Future<void> deleteKey() async {
    await _storage.delete(key: _key);
  }
}
