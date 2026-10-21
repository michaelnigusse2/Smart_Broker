import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/note_repository.dart';
import 'app_log.dart';
import 'overlay_draft_service.dart';

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

  static Future<void> write(Map<String, dynamic> state) => _prefs.setString(_stateKey, jsonEncode(state));

  static Future<void> clear() => _prefs.remove(_stateKey);

  // ── Call placed from the app ───────────────────────────────────
  //
  // Android doesn't tell us the number of an outgoing call until it's in the
  // call log, so the Call buttons note who they dial; the call that starts
  // within two minutes is taken to be that one.

  static const _expectedKey = 'expected_outgoing_call';

  static Future<void> expectOutgoing(String number) =>
      _prefs.setString(_expectedKey, jsonEncode({'number': number, 'at': DateTime.now().millisecondsSinceEpoch}));

  /// The number dialled from the app in the last two minutes, if any (once).
  static Future<String?> takeExpectedOutgoing() async {
    final raw = await _prefs.getString(_expectedKey);
    if (raw == null) return null;
    await _prefs.remove(_expectedKey);
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final at = DateTime.fromMillisecondsSinceEpoch(data['at'] as int);
      if (DateTime.now().difference(at) > const Duration(minutes: 2)) return null;
      return data['number'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Drops the current-call state and any note waiting for AI review.
  static Future<void> clearAll() async {
    await _prefs.remove(_stateKey);
    await _prefs.remove(_pendingReviewKey);
  }

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

  /// Saves a review taken with [takePendingReview] as a note (main app only).
  /// Returns the note id, or null if the write failed — AI Review then gets
  /// the text and saves it itself.
  static Future<String?> savePendingNote(Map<String, dynamic> pending) async {
    try {
      final contactId = pending['contactId'] as String;
      final id = await NoteRepository().saveNote(contactId: contactId, rawText: pending['rawText'] as String);
      // The note is saved now; the overlay draft would otherwise come back on the next call.
      await OverlayDraftService().clearDraft(contactId);
      return id;
    } catch (e, st) {
      AppLog.e('CallOverlayState', 'could not save the note from the overlay', e, st);
      return null;
    }
  }
}
