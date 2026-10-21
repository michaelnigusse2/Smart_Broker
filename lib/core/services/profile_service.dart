import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the person does, chosen in onboarding. Later it decides which fields
/// and deal stages the app starts with (real estate adds budget, bedrooms, area).
enum WorkType {
  company('I run a company'),
  sales('I sell'),
  realEstate('Real estate'),
  other('Something else')
  ;

  const WorkType(this.label);
  final String label;

  static WorkType? byName(String? name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// The person using the app: their name, their work, and whether they've
/// finished onboarding. Stored on the phone only.
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static const _keyName = 'profile_name';
  static const _keyWork = 'profile_work';
  static const _keyOnboarded = 'onboarding_done_v1';
  static const _keyLanguage = 'profile_language';

  /// The saved first name, for screens that greet the person.
  static final ValueNotifier<String> name = ValueNotifier('');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name.value = prefs.getString(_keyName) ?? '';
  }

  Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName) ?? '';
  }

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, trimmed);
    name.value = trimmed;
  }

  Future<WorkType?> getWork() async {
    final prefs = await SharedPreferences.getInstance();
    return WorkType.byName(prefs.getString(_keyWork));
  }

  Future<void> setWork(WorkType value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWork, value.name);
  }

  /// 'en' or 'am', chosen on the welcome screen.
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, value);
  }

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarded) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, value);
  }
}
