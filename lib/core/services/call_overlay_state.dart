import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// State shared between the main app and the call overlay.
///
/// The overlay runs in its own Flutter engine (a separate isolate), so the two
/// sides can't share memory. Message passing through flutter_overlay_window is
/// not reliable in the overlay → app direction, so both sides read and write
/// this small store instead. `SharedPreferencesAsync` is used because it never
/// caches, so each isolate always sees the other's latest writes.
class CallOverlayState {
  static const _stateKey = 'call_overlay_state';
  static const _pendingReviewKey = 'pending_ai_review';

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // ── Current call ───────────────────────────────────────────────
  //
  // Keys: phase ('ringing' | 'active' | 'ended'), number, contactId,
  // contactName, pendingTasks (List<String>), lastNoteSummary,
  // startedAt / endedAt (ms since epoch).

  static Future<Map<String, dynamic>?> read() async {
    final raw = await _prefs.getString(_stateKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(Map<String, dynamic> state) =>
      _prefs.setString(_stateKey, jsonEncode(state));

  static Future<void> clear() => _prefs.remove(_stateKey);

  // ── Note waiting for AI review ─────────────────────────────────
  //
  // Written by the overlay's "Save & Process"; picked up by the app the next
  // time it's opened (or when the post-call notification is tapped).

  static Future<void> setPendingReview({String? contactId, required String text}) {
    return _prefs.setString(
      _pendingReviewKey,
      jsonEncode({'contactId': contactId, 'text': text}),
    );
  }

  static Future<Map<String, dynamic>?> peekPendingReview() async {
    final raw = await _prefs.getString(_pendingReviewKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Fills in the contact once the call has been matched (e.g. the note was
  /// saved while the call was still ringing and the number wasn't known yet).
  static Future<void> attachContactToPendingReview(String contactId) async {
    final pending = await peekPendingReview();
    if (pending == null || pending['contactId'] != null) return;
    await setPendingReview(contactId: contactId, text: pending['text'] as String? ?? '');
  }

  static bool _taking = false;

  /// When a pending review was last opened — lets the notification handler
  /// tell that the app's resume handler already took care of it.
  static DateTime? lastTakenAt;

  static bool get tookRecently =>
      lastTakenAt != null && DateTime.now().difference(lastTakenAt!) < const Duration(seconds: 5);

  /// Returns the pending review (with a contact) and removes it, or null.
  /// Guarded so two callers (app resume + notification tap) can't both take it.
  static Future<Map<String, dynamic>?> takePendingReview() async {
    if (_taking) return null;
    _taking = true;
    try {
      final pending = await peekPendingReview();
      if (pending == null) return null;
      final contactId = pending['contactId'] as String?;
      final text = (pending['text'] as String? ?? '').trim();
      if (contactId == null || text.isEmpty) return null;
      await _prefs.remove(_pendingReviewKey);
      lastTakenAt = DateTime.now();
      return {'contactId': contactId, 'rawText': text};
    } finally {
      _taking = false;
    }
  }
}
