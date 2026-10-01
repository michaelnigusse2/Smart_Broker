import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../models/call_entry.dart';
import '../../models/call_event.dart';
import '../../models/contact.dart';
import '../../models/phone_contact.dart';
import '../repositories/call_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/todo_repository.dart';
import 'call_detection_service.dart';
import 'call_overlay_state.dart';
import 'notification_service.dart';
import 'settings_service.dart';

/// Turns native call events into app behaviour:
/// - shows the live call overlay (ringing → active → ended) with the caller's context,
/// - logs finished calls against the matching contact,
/// - shows the "add a note" notification after a call.
class CallMatchingService {
  static final CallMatchingService _instance = CallMatchingService._internal();
  factory CallMatchingService() => _instance;
  CallMatchingService._internal();

  final CallRepository _callRepo = CallRepository();
  final ContactRepository _contactRepo = ContactRepository();
  final CallDetectionService _detectionService = CallDetectionService();
  final SettingsService _settings = SettingsService();

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
      onError: (e) => debugPrint('CallMatchingService: event stream error: $e'),
    );
    debugPrint('CallMatchingService: started listening for call events');
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('CallMatchingService: stopped listening');
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
      debugPrint('CallMatchingService: error handling $data: $e\n$st');
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
          await _updateOverlay({
            'phase': 'active',
            'startedAt': DateTime.now().millisecondsSinceEpoch,
            if (hasNumber) 'number': number,
          });
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
    await _updateOverlay({'number': number, ...await _contextFor(number)});
  }

  Future<bool> _overlayAllowed() async {
    if (!await _settings.getShowCallOverlay()) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  Future<void> _startOverlay({required String phase, String? number}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await CallOverlayState.write({
      'phase': phase,
      'number': number,
      'startedAt': now,
      if (number != null) ...await _contextFor(number),
    });

    if (!await _overlayAllowed()) return;
    try {
      if (!await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.showOverlay(
          // Top half of the screen: leaves the dialer's buttons usable and
          // room below for the keyboard. Height is in physical pixels.
          height: _overlayHeightPx(),
          width: WindowSize.matchParent,
          alignment: OverlayAlignment.topCenter,
          // focusPointer lets the note field receive keyboard input while
          // touches outside the window still reach the dialer.
          flag: OverlayFlag.focusPointer,
          enableDrag: true,
          positionGravity: PositionGravity.none,
          visibility: NotificationVisibility.visibilityPrivate,
          overlayTitle: 'SmartBroker',
          overlayContent: 'Call notes',
        );
      }
      await _notifyOverlay();
    } catch (e) {
      debugPrint('CallMatchingService: could not show overlay: $e');
    }
  }

  int _overlayHeightPx() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 1200;
    return (views.first.physicalSize.height * 0.5).round();
  }

  Future<void> _updateOverlay(Map<String, dynamic> changes) async {
    final state = await CallOverlayState.read() ?? {};
    state.addAll(changes);
    await CallOverlayState.write(state);
    await _notifyOverlay();
  }

  /// Nudges the overlay to re-read the shared state right away (it also polls).
  Future<void> _notifyOverlay() async {
    try {
      await FlutterOverlayWindow.shareData({'action': 'refresh'});
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

  Future<Contact?> _findContact(String number) async {
    final contacts = await _contactRepo.getAll();
    for (final c in contacts) {
      if (PhoneContact.numbersMatch(c.phoneNumber, number)) return c;
    }
    return null;
  }

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
      debugPrint('CallMatchingService: processing call from $normalizedNumber (${event.type.name})');

      if (normalizedNumber.isEmpty) {
        debugPrint('CallMatchingService: empty phone number, skipping');
        return null;
      }

      Contact contact;
      final match = await _findContact(event.phoneNumber);
      if (match != null) {
        contact = match.copyWith(lastInteraction: event.timestamp);
        await _contactRepo.update(contact);
        debugPrint('CallMatchingService: matched to contact "${match.name}"');
      } else {
        // TODO: unknown numbers — decide between auto-creating and an "unassigned calls" inbox.
        final id = await _contactRepo.insert(Contact(
          id: '',
          name: normalizedNumber,
          phoneNumber: event.phoneNumber,
          lastInteraction: event.timestamp,
        ));
        contact = (await _contactRepo.getById(id))!;
        debugPrint('CallMatchingService: created contact "$normalizedNumber" → $id');
      }

      final callId = await _callRepo.insert(CallEntry(
        id: '',
        contactId: contact.id,
        type: event.type,
        duration: event.duration,
        timestamp: event.timestamp,
      ));
      final callEntry = CallEntry(
        id: callId,
        contactId: contact.id,
        type: event.type,
        duration: event.duration,
        timestamp: event.timestamp,
      );
      debugPrint('CallMatchingService: logged ${event.type.name} call (${event.duration.inSeconds}s)');
      _onCallLoggedController.add(callEntry);

      final promptEnabled = await _settings.getPromptAfterCall();
      final minDuration = await _settings.getMinCallDuration();
      if (promptEnabled && event.type != CallType.missed && event.duration.inSeconds >= minDuration) {
        await NotificationService().showPostCallPrompt(contact, callEntry);
      }
      return contact;
    } catch (e) {
      debugPrint('CallMatchingService: error processing call event: $e');
      return null;
    }
  }
}
