import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider.dart';

/// When the live call overlay appears.
enum OverlayMode {
  /// Only for numbers that belong to a SmartBroker contact (default).
  /// Unknown callers also get no post-call prompt.
  knownOnly,

  /// For every call.
  all,

  /// Never.
  off;

  static OverlayMode? byName(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyPromptAfterCall = 'prompt_after_call';
  static const String _keyMinCallDuration = 'min_call_duration_seconds';
  /// Legacy on/off switch, read once to migrate to [_keyOverlayMode].
  static const String _keyShowCallOverlay = 'show_call_overlay';
  static const String _keyOverlayMode = 'overlay_mode';
  static const String _keyCallDetectionEnabled = 'call_detection_enabled';
  static const String _keyAiProvider = 'ai_provider';
  static const String _keyAiConsentProvider = 'ai_consent_provider';
  static const String _keyAiModelPrefix = 'ai_model_';

  // Default values
  static const bool _defaultPromptAfterCall = true;
  static const int _defaultMinCallDuration = 10;

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

  Future<OverlayMode> getOverlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = OverlayMode.byName(prefs.getString(_keyOverlayMode));
    if (saved != null) return saved;
    // Before overlay modes there was a plain switch; "off" stays off.
    return prefs.getBool(_keyShowCallOverlay) == false ? OverlayMode.off : OverlayMode.knownOnly;
  }

  Future<void> setOverlayMode(OverlayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOverlayMode, mode.name);
    await prefs.remove(_keyShowCallOverlay);
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

  /// Whether the user accepted the AI data notice for [provider]. Consent is
  /// tied to one provider, so switching provider asks again.
  Future<bool> hasAiConsent(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiConsentProvider) == provider.id;
  }

  Future<void> setAiConsent(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiConsentProvider, provider.id);
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
