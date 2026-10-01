import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyPromptAfterCall = 'prompt_after_call';
  static const String _keyMinCallDuration = 'min_call_duration_seconds';
  static const String _keyShowCallOverlay = 'show_call_overlay';
  static const String _keyCallDetectionEnabled = 'call_detection_enabled';
  static const String _keyAiProvider = 'ai_provider';
  static const String _keyAiModelPrefix = 'ai_model_';

  // Default values
  static const bool _defaultPromptAfterCall = true;
  static const int _defaultMinCallDuration = 10;
  static const bool _defaultShowCallOverlay = true;

  Future<bool> getPromptAfterCall() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPromptAfterCall) ?? _defaultPromptAfterCall;
  }

  Future<void> setPromptAfterCall(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPromptAfterCall, value);
  }

  Future<int> getMinCallDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMinCallDuration) ?? _defaultMinCallDuration;
  }

  Future<void> setMinCallDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMinCallDuration, seconds);
  }

  Future<bool> getShowCallOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowCallOverlay) ?? _defaultShowCallOverlay;
  }

  Future<void> setShowCallOverlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowCallOverlay, value);
  }

  /// Whether the user turned call detection on (restarted on every app launch).
  Future<bool> getCallDetectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCallDetectionEnabled) ?? false;
  }

  Future<void> setCallDetectionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCallDetectionEnabled, value);
  }

  // ── AI provider ────────────────────────────────────────────────

  Future<AiProvider> getAiProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return AiProvider.byId(prefs.getString(_keyAiProvider));
  }

  Future<void> setAiProvider(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiProvider, provider.id);
  }

  /// The model to use for [provider]: the user's override, or its default.
  Future<String> getAiModel(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final model = prefs.getString('$_keyAiModelPrefix${provider.id}');
    return (model == null || model.trim().isEmpty) ? provider.defaultModel : model.trim();
  }

  /// Saves a model override; an empty value or the default clears it.
  Future<void> setAiModel(AiProvider provider, String model) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyAiModelPrefix${provider.id}';
    final trimmed = model.trim();
    if (trimmed.isEmpty || trimmed == provider.defaultModel) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
  }
}
