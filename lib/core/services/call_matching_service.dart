import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/call_entry.dart';
import '../../models/call_event.dart';
import '../../models/contact.dart';
import '../../models/phone_contact.dart';
import '../repositories/call_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/todo_repository.dart';
import 'app_log.dart';
import 'call_detection_service.dart';
import 'call_overlay_state.dart';
import 'notification_service.dart';
import 'overlay_gateway.dart';
import 'settings_service.dart';

/// Whether the live overlay should be visible for a call.
///
/// [number] is null while it isn't known yet: Android reports the caller's
/// number a moment after "ringing", and never reports it for outgoing calls
/// until the call log is written. In [OverlayMode.knownOnly] a ringing call
/// waits for the number; an answered or outgoing call without one is shown,
/// because the user chose to take part in it.
@visibleForTesting
bool shouldShowOverlay({
  required OverlayMode mode,
  required String phase,
  required String? number,
  required bool isKnownContact,
}) {
  switch (mode) {
    case OverlayMode.off:
      return false;
    case OverlayMode.all:
      return true;
    case OverlayMode.knownOnly:
      if (number != null && number.isNotEmpty) return isKnownContact;
      return phase == 'active';
  }
}

/// Whether to show the "add a note" notification after a call. Unknown
/// callers only get one in [OverlayMode.all] (until the unassigned-calls inbox).
@visibleForTesting
bool shouldPromptAfterCall({
  required bool promptEnabled,
  required OverlayMode mode,
  required CallType type,
  required Duration duration,
  required Duration minDuration,
  required bool isKnownContact,
}) {
  if (!promptEnabled || type == CallType.missed || duration < minDuration) return false;
  return isKnownContact || mode == OverlayMode.all;
}

/// Turns native call events into app behaviour:
/// - shows the live call overlay (ringing → active → ended) with the caller's context,
/// - logs finished calls against the matching contact,
/// - shows the "add a note" notification after a call.
class CallMatchingService {
  static final CallMatchingService _instance = CallMatchingService._internal();
  factory CallMatchingService() => _instance;
  CallMatchingService._internal();

  static const _tag = 'CallMatching';

  final CallRepository _callRepo = CallRepository();
  final ContactRepository _contactRepo = ContactRepository();
  final CallDetectionService _detectionService = CallDetectionService();
  final SettingsService _settings = SettingsService();

  @visibleForTesting
  OverlayGateway overlay = const OverlayGateway();

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final StreamController<CallEntry> _onCallLoggedController = StreamController<CallEntry>.broadcast();

  /// Stream of recently logged calls, used to auto-refresh UI.
  Stream<CallEntry> get onCallLogged => _onCallLoggedController.stream;

  /// True between the first ringing/off-hook event and the end of the call.
  bool _callInProgress = false;

  bool get isListening => _subscription != null;

  /// Start listening for call events from the native service.
  void startListening() {
    _subscription?.cancel();
    _subscription = _detectionService.callEvents.listen(
      _handleRawEvent,
      onError: (e) => AppLog.w(_tag, 'event stream error', e),
    );
    AppLog.i(_tag, 'started listening for call events');
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    AppLog.i(_tag, 'stopped listening');
  }

  /// Logs a finished call directly (no overlay). Kept for tests/tools.
  Future<void> handleCallEvent(CallEvent event) => _logCall(event);

  /// Plays a whole call through the same code path as a real one, so the
  /// overlay, logging and post-call prompt can be tested without a phone call.
  Future<void> simulateCall({
    required String phoneNumber,
    required CallType type,
    required Duration duration,
  }) async {
    final start = DateTime.now();
    if (type == CallType.outgoing) {
      await _handleRawEvent({'event': 'state', 'state': 'offhook', 'number': phoneNumber});
    } else {
      await _handleRawEvent({'event': 'state', 'state': 'ringing', 'number': phoneNumber});
      await Future.delayed(const Duration(seconds: 4));
      if (type == CallType.incoming) {
        await _handleRawEvent({'event': 'state', 'state': 'offhook'});
      }
    }
    if (type != CallType.missed) {
      // Keep the "active" phase short enough to test comfortably.
      await Future.delayed(Duration(seconds: math.min(duration.inSeconds, 30)));
    }
    await _handleRawEvent({'event': 'state', 'state': 'idle'});
    await _handleRawEvent({
      'event': 'call_logged',
      'phoneNumber': phoneNumber,
      'type': type.name,
      'duration': type == CallType.missed ? 0 : duration.inSeconds,
      'timestamp': start.millisecondsSinceEpoch,
    });
  }

  Future<void> _handleRawEvent(Map<String, dynamic> data) async {
    try {
      switch (data['event'] as String?) {
        case 'state':
          await _handleStateChange(data['state'] as String?, data['number'] as String?);
        case 'incoming_number':
          await _handleIncomingNumber(data['number'] as String?);
        case 'call_logged':
          await _handleCallLogged(CallEvent.fromMap(data));
      }
    } catch (e, st) {
      AppLog.e(_tag, 'error handling ${data['event']} event', e, st);
    }
  }

  // ── Live call (overlay) ────────────────────────────────────────

  Future<void> _handleStateChange(String? state, String? number) async {
    final hasNumber = number != null && number.isNotEmpty;
    switch (state) {
      case 'ringing':
        _callInProgress = true;
        await _startOverlay(phase: 'ringing', number: hasNumber ? number : null);
      case 'offhook':
        if (!_callInProgress) {
          // Outgoing call (or we missed the ringing event).
          _callInProgress = true;
          await _startOverlay(phase: 'active', number: hasNumber ? number : null);
        } else {
          final updated = await _updateOverlay({
            'phase': 'active',
            'startedAt': DateTime.now().millisecondsSinceEpoch,
            if (hasNumber) 'number': number,
            if (hasNumber) ...await _contextFor(number),
          });
          // A ringing call from a not-yet-known number may not be showing yet.
          await _showOverlayIfWanted(updated);
        }
      case 'idle':
        if (!_callInProgress) return; // Initial idle state when listening starts.
        _callInProgress = false;
        await _updateOverlay({
          'phase': 'ended',
          'endedAt': DateTime.now().millisecondsSinceEpoch,
        });
    }
  }

  Future<void> _handleIncomingNumber(String? number) async {
    if (number == null || number.isEmpty || !_callInProgress) return;
    final state = await CallOverlayState.read();
    if (state == null || (state['contactId'] as String?) != null) return;
    final updated = await _updateOverlay({'number': number, ...await _contextFor(number)});
    await _showOverlayIfWanted(updated);
  }

  /// Whether a call from [number] would show the overlay right now (mode,
  /// contact match and permission). Used by Settings → Simulate Call.
  Future<bool> overlayWouldShowFor(String number) async {
    final known = (await _findContact(number)) != null;
    final mode = await _settings.getOverlayMode();
    return shouldShowOverlay(mode: mode, phase: 'ringing', number: number, isKnownContact: known) &&
        await overlay.isPermissionGranted();
  }

  Future<void> _startOverlay({required String phase, String? number}) async {
    final state = {
      'phase': phase,
      'number': number,
      'startedAt': DateTime.now().millisecondsSinceEpoch,
      if (number != null) ...await _contextFor(number),
    };
    await CallOverlayState.write(state);
    await _showOverlayIfWanted(state);
  }

  /// Shows the overlay for the current call [state] if the overlay mode allows it.
  Future<void> _showOverlayIfWanted(Map<String, dynamic> state) async {
    final number = state['number'] as String?;
    final mode = await _settings.getOverlayMode();
    final wanted = shouldShowOverlay(
      mode: mode,
      phase: state['phase'] as String? ?? 'ringing',
      number: number,
      isKnownContact: state['contactId'] != null,
    );
    if (!wanted) {
      AppLog.d(_tag, 'overlay not shown (mode ${mode.name}, ${number == null ? 'number unknown' : 'unknown caller'})');
      return;
    }
    if (!await overlay.isPermissionGranted()) return;
    try {
      if (!await overlay.isActive()) {
        // Top half of the screen: leaves the dialer's buttons usable and
        // room below for the keyboard.
        await overlay.show(heightPx: _overlayHeightPx());
      }
      await _notifyOverlay();
    } catch (e) {
      AppLog.w(_tag, 'could not show overlay', e);
    }
  }

  int _overlayHeightPx() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 1200;
    return (views.first.physicalSize.height * 0.5).round();
  }

  /// Merges [changes] into the shared call state and returns the result.
  Future<Map<String, dynamic>> _updateOverlay(Map<String, dynamic> changes) async {
    final state = await CallOverlayState.read() ?? {};
    state.addAll(changes);
    await CallOverlayState.write(state);
    await _notifyOverlay();
    return state;
  }

  /// Nudges the overlay to re-read the shared state right away (it also polls).
  Future<void> _notifyOverlay() async {
    try {
      await overlay.shareData({'action': 'refresh'});
    } catch (_) {}
  }

  /// Contact name, id, open tasks and last note summary for a phone number.
  Future<Map<String, dynamic>> _contextFor(String number) async {
    final contact = await _findContact(number);
    if (contact == null) return {};
    final todos = await TodoRepository().getByContactId(contact.id);
    final notes = await NoteRepository().getByContactId(contact.id);
    return {
      'contactId': contact.id,
      'contactName': contact.name,
      'pendingTasks': todos.where((t) => !t.isCompleted).take(5).map((t) => t.title).toList(),
      'lastNoteSummary': notes.isNotEmpty ? notes.first.aiSummary : '',
    };
  }

  Future<Contact?> _findContact(String number) => _contactRepo.findByPhone(number);

  // ── Finished call (log + prompt) ───────────────────────────────

  Future<void> _handleCallLogged(CallEvent event) async {
    final contact = await _logCall(event);
    if (contact == null) return;

    // Let the overlay know who the call was with (needed for outgoing calls,
    // where the number is only known once the call log is written).
    final state = await CallOverlayState.read();
    if (state != null) {
      await _updateOverlay({
        'number': event.phoneNumber,
        ...await _contextFor(event.phoneNumber),
      });
    }
    await CallOverlayState.attachContactToPendingReview(contact.id);
  }

  /// Matches the call to a contact (creating one if needed), logs it, and
  /// shows the post-call prompt. Returns the contact, or null if skipped.
  Future<Contact?> _logCall(CallEvent event) async {
    try {
      final normalizedNumber = PhoneContact.normalizePhoneNumber(event.phoneNumber);
      AppLog.d(_tag, 'processing ${event.type.name} call from ${AppLog.maskPhone(normalizedNumber)}');

      if (normalizedNumber.isEmpty) {
        AppLog.d(_tag, 'empty phone number, skipping');
        return null;
      }

      Contact contact;
      final match = await _findContact(event.phoneNumber);
      final isKnownContact = match != null;
      if (match != null) {
        await _contactRepo.touch(match.id, event.timestamp);
        contact = match;
        AppLog.d(_tag, 'matched to contact ${match.id}');
      } else {
        // TODO: unknown numbers — decide between auto-creating and an "unassigned calls" inbox.
        final id = await _contactRepo.insert(
          Contact(
            id: '',
            name: normalizedNumber,
            phoneNumber: event.phoneNumber,
            lastInteraction: event.timestamp,
          ),
        );
        contact = (await _contactRepo.getById(id))!;
        AppLog.d(_tag, 'created contact $id for unknown caller');
      }

      // The call log can report the same call again (e.g. after a restart).
      if (await _callRepo.exists(contact.id, event.timestamp)) {
        AppLog.d(_tag, 'call already logged, skipping');
        return contact;
      }

      final callId = await _callRepo.insert(
        CallEntry(
          id: '',
          contactId: contact.id,
          type: event.type,
          duration: event.duration,
          timestamp: event.timestamp,
        ),
      );
      final callEntry = CallEntry(
        id: callId,
        contactId: contact.id,
        type: event.type,
        duration: event.duration,
        timestamp: event.timestamp,
      );
      AppLog.d(_tag, 'logged ${event.type.name} call (${event.duration.inSeconds}s)');
      _onCallLoggedController.add(callEntry);

      final prompt = shouldPromptAfterCall(
        promptEnabled: await _settings.getPromptAfterCall(),
        mode: await _settings.getOverlayMode(),
        type: event.type,
        duration: event.duration,
        minDuration: Duration(seconds: await _settings.getMinCallDuration()),
        isKnownContact: isKnownContact,
      );
      if (prompt) await NotificationService().showPostCallPrompt(contact, callEntry);
      return contact;
    } catch (e) {
      AppLog.e(_tag, 'error processing call event', e);
      return null;
    }
  }
}
