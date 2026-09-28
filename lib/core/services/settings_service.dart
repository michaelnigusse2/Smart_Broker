import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyPromptAfterCall = 'prompt_after_call';
  static const String _keyMinCallDuration = 'min_call_duration_seconds';
  static const String _keyShowCallOverlay = 'show_call_overlay';

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
}
