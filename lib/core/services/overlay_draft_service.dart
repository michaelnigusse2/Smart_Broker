import 'package:shared_preferences/shared_preferences.dart';

/// Notes typed in the call overlay, kept per contact until they're processed.
///
/// Uses `SharedPreferencesAsync` (no in-memory cache) because drafts are written
/// by the overlay's engine and read by the main app's engine.
class OverlayDraftService {
  static const _prefix = 'overlay_draft_';
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<void> saveDraft(String contactId, String text) => _prefs.setString('$_prefix$contactId', text);

  Future<String?> loadDraft(String contactId) => _prefs.getString('$_prefix$contactId');

  Future<void> clearDraft(String contactId) => _prefs.remove('$_prefix$contactId');
}
