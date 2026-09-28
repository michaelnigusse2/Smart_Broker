import 'package:shared_preferences/shared_preferences.dart';

class OverlayDraftService {
  static const _prefix = 'overlay_draft_';

  Future<void> saveDraft(String contactId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$contactId', text);
  }

  Future<String?> loadDraft(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$contactId');
  }

  Future<void> clearDraft(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$contactId');
  }
}
