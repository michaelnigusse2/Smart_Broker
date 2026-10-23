import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_log.dart';
import 'app_theme.dart';

/// What you picked under Settings, Appearance.
@immutable
class Appearance {
  const Appearance({this.theme = AppThemeName.ink, this.mode = ThemeMode.system});

  final AppThemeName theme;

  /// Light, dark, or follow the phone.
  final ThemeMode mode;

  Appearance copyWith({AppThemeName? theme, ThemeMode? mode}) =>
      Appearance(theme: theme ?? this.theme, mode: mode ?? this.mode);

  @override
  bool operator ==(Object other) => other is Appearance && other.theme == theme && other.mode == mode;

  @override
  int get hashCode => Object.hash(theme, mode);
}

/// The app's theme and light/dark choice. Kept in `SharedPreferencesAsync`
/// so the call overlay (a separate Flutter engine) reads the same values.
class AppearanceController extends ValueNotifier<Appearance> {
  AppearanceController._() : super(const Appearance());

  static final instance = AppearanceController._();

  static const _themeKey = 'appearance_theme';
  static const _modeKey = 'appearance_mode';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  /// Reads the saved choice (Ink and the phone's light/dark when nothing is saved).
  static Future<Appearance> read() async {
    try {
      final prefs = SharedPreferencesAsync();
      final theme = AppThemeName.fromName(await prefs.getString(_themeKey));
      final modeName = await prefs.getString(_modeKey);
      final mode = ThemeMode.values.firstWhere((m) => m.name == modeName, orElse: () => ThemeMode.system);
      return Appearance(theme: theme, mode: mode);
    } catch (e) {
      AppLog.w('Appearance', 'could not read appearance', e);
      return const Appearance();
    }
  }

  Future<void> load() async => value = await read();

  Future<void> setTheme(AppThemeName theme) async {
    value = value.copyWith(theme: theme);
    await _prefs.setString(_themeKey, theme.name);
  }

  Future<void> setMode(ThemeMode mode) async {
    value = value.copyWith(mode: mode);
    await _prefs.setString(_modeKey, mode.name);
  }
}
