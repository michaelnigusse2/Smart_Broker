import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/call_entry.dart';
import '../../models/call_event.dart';
import '../../models/contact.dart';
import '../../models/phone_contact.dart';
import '../../models/todo_item.dart';
import '../repositories/call_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/new_number_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/todo_repository.dart';
import '../utils/call_backs.dart';
import '../utils/day_labels.dart';
import 'app_log.dart';
import 'call_detection_service.dart';
import 'call_overlay_state.dart';
import 'notification_service.dart';
import 'phone_contact_service.dart';
import 'overlay_gateway.dart';
import 'settings_service.dart';
import 'wrap_up_store.dart';

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

/// Whether to show the "add a note" notification after a call with one of
/// your people. (A new number gets "Who was this?" instead:
/// [shouldAskWhoWasThis].)
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

/// Whether to ask "Who was this?" after a call with a new number: you
/// talked (not missed, not too short) and after-call notes are on.
@visibleForTesting
bool shouldAskWhoWasThis({
  required bool promptEnabled,
  required CallType type,
  required Duration duration,
  required Duration minDuration,
}) => promptEnabled && type != CallType.missed && duration > Duration.zero && duration >= minDuration;

/// The moments marked during a call, timed from when talking started.
///
/// On a call you placed, the overlay counts from dialling (Android doesn't
/// say when the other side answers), so the ringing time is taken off using
/// the call log's length, which counts talk time only.
@visibleForTesting
List<Map<String, dynamic>> talkTimeMarks(Map<String, dynamic>? state, Duration talked) {
  final marks = [for (final m in (state?['marks'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
  final started = state?['startedAt'];
  final ended = state?['endedAt'];
  if (state?['outgoing'] != true || started is! int || ended is! int) return marks;
  final ringing = math.max(0, (ended - started) ~/ 1000 - talked.inSeconds);
  return [
    for (final m in marks) {...m, 'at': math.max(0, (m['at'] as int? ?? 0) - ringing)},
  ];
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
    AppLog.d(_tag, 'call state: $state');
    final hasNumber = number != null && number.isNotEmpty;
    switch (state) {
      case 'ringing':
        _callInProgress = true;
        await _startOverlay(phase: 'ringing', number: hasNumber ? number : null);
      case 'offhook':
        if (!_callInProgress) {
          // Outgoing call (or we missed the ringing event). A call placed
          // from the app's Call button tells us who it's with.
          _callInProgress = true;
          final expected = hasNumber ? null : await CallOverlayState.takeExpectedOutgoing();
          // Android reports "off the hook" the moment you dial; it never says
          // when the other side answers. The overlay knows not to start a
          // talk timer for these.
          await _startOverlay(phase: 'active', number: hasNumber ? number : expected, outgoing: true);
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

  Future<void> _startOverlay({required String phase, String? number, bool outgoing = false}) async {
    final state = {
      'phase': phase,
      'number': number,
      'outgoing': outgoing,
      'topInset': _statusBarHeight(),
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
    // The person tapped "Hide" on the ringing card: stay away for this call.
    if (state['hidden'] == true) return;
    // "Not a client": no card for this number.
    if (state['contactId'] == null &&
        number != null &&
        await NewNumberRepository().isIgnored(PhoneContact.matchKey(number))) {
      return;
    }
    if (!await overlay.isPermissionGranted()) return;
    try {
      if (!await overlay.isActive()) {
        // Just the ringing card at the top; the overlay then fits the window
        // to whatever it shows, so the phone's own buttons stay free.
        await overlay.show(heightPx: _overlayHeightPx());
      }
      await _notifyOverlay();
    } catch (e) {
      AppLog.w(_tag, 'could not show overlay', e);
    }
  }

  /// Status bar height in logical pixels, so the overlay can keep its header
  /// below it (the overlay window itself receives no insets).
  double _statusBarHeight() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 28;
    final view = views.first;
    final top = view.viewPadding.top / view.devicePixelRatio;
    return top > 0 ? top : 28;
  }

  /// About the ringing card's height (status bar, margin, card, shadow).
  int _overlayHeightPx() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 600;
    final view = views.first;
    return ((_statusBarHeight() + 12 + 156 + 16) * view.devicePixelRatio).round();
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

  /// Who is on the call, for the overlay: name, company, when you last
  /// talked, the first thing you owe them, open tasks and the last note.
  Future<Map<String, dynamic>> _contextFor(String number) async {
    final contact = await _findContact(number);
    if (contact == null) return {};
    final todos = await TodoRepository().getByContactId(contact.id);
    final notes = await NoteRepository().getByContactId(contact.id);
    final owed = todos.where((t) => !t.isCompleted && t.owedBy == OwedBy.me).toList()
      ..sort((a, b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
    return {
      'contactId': contact.id,
      'contactName': contact.name,
      'company': contact.company.trim().isNotEmpty ? contact.company.trim() : contact.role.trim(),
      'lastTalkAt': contact.lastInteraction.millisecondsSinceEpoch,
      'owe': owed.isEmpty ? '' : owed.first.title,
      'pendingTasks': todos.where((t) => !t.isCompleted).take(5).map((t) => t.title).toList(),
      // An unprocessed note has no summary yet: show its text instead.
      'lastNoteSummary': notes.isEmpty
          ? ''
          : (notes.first.aiSummary.trim().isNotEmpty ? notes.first.aiSummary : notes.first.rawText).trim(),
    };
  }

  Future<Contact?> _findContact(String number) => _contactRepo.findByPhone(number);

  // ── Finished call (log + prompt) ───────────────────────────────

  Future<void> _handleCallLogged(CallEvent event) async {
    // What the overlay gathered during the call (marks), read before the
    // call is logged. Only a call that has ended is this one: a call still
    // ringing or on is a newer call (this one was logged late), whose state
    // stays as it is.
    final read = await CallOverlayState.read();
    final state = read?['phase'] == 'ended' ? read : null;
    final contact = await _logCall(
      event,
      marks: talkTimeMarks(state, event.duration),
    );
    // The call is over and handed to the notification: the overlay state
    // has done its job. The overlay closes itself on "ended" (or when the
    // state is gone, if it was too slow to see "ended").
    if (state != null) {
      await CallOverlayState.clear();
      await _notifyOverlay();
      unawaited(_closeOverlayLater());
    }
    if (contact == null) return;
    await CallOverlayState.attachContactToPendingReview(contact.id);
  }

  /// Last resort for a call card still on screen after its call was logged
  /// (the overlay closes itself on "ended"; this covers a stalled overlay).
  Future<void> _closeOverlayLater() async {
    await Future.delayed(const Duration(seconds: 3));
    if (_callInProgress) return; // A new call has started meanwhile.
    try {
      if (await overlay.isActive()) {
        AppLog.d(_tag, 'closing a call card left on screen');
        await overlay.close();
      }
    } catch (_) {}
  }

  /// Matches the call to a contact (creating one if needed), logs it, and
  /// shows the after-call notification, keeping the call on the wrap-up list
  /// until it's settled or noted. Returns the contact, or null if skipped.
  Future<Contact?> _logCall(CallEvent event, {List<Map<String, dynamic>> marks = const []}) async {
    try {
      final normalizedNumber = PhoneContact.normalizePhoneNumber(event.phoneNumber);
      AppLog.d(_tag, 'processing ${event.type.name} call from ${AppLog.maskPhone(normalizedNumber)}');

      if (normalizedNumber.isEmpty) {
        AppLog.d(_tag, 'empty phone number, skipping');
        return null;
      }

      final match = await _findContact(event.phoneNumber) ?? await _fromPhoneContacts(event);
      if (match == null) return _logNewNumber(event);
      const isKnownContact = true;
      await _contactRepo.touch(match.id, event.timestamp);
      final contact = match;
      AppLog.d(_tag, 'matched to contact ${match.id}');

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

      // You talked: their missed calls are answered.
      if (event.type != CallType.missed && event.duration > Duration.zero) {
        await _closeCallBacks(contact.id);
      }
      if (event.type == CallType.missed) {
        await _notifyMissed(contact, callEntry);
        return contact;
      }

      final prompt = shouldPromptAfterCall(
        promptEnabled: await _settings.getPromptAfterCall(),
        mode: await _settings.getOverlayMode(),
        type: event.type,
        duration: event.duration,
        minDuration: Duration(seconds: await _settings.getMinCallDuration()),
        isKnownContact: isKnownContact,
      );
      if (prompt) {
        final owed =
            (await TodoRepository().getByContactId(
                contact.id,
              )).where((t) => !t.isCompleted && t.owedBy == OwedBy.me).toList()
              ..sort((a, b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
        final owe = owed.isEmpty ? '' : owed.first.title;
        await WrapUpStore.add(
          WrapUp(
            callId: callId,
            contactId: contact.id,
            name: contact.name,
            seconds: event.duration.inSeconds,
            at: event.timestamp,
            owe: owe,
            marks: marks,
          ),
        );
        await NotificationService().showPostCallPrompt(contact, callEntry, owe: owe, marks: marks.length);
      }
      return contact;
    } catch (e) {
      AppLog.e(_tag, 'error processing call event', e);
      return null;
    }
  }

  /// A number saved in the phone's own contacts (but not in the app) becomes
  /// one of your people, by the name you saved it under.
  Future<Contact?> _fromPhoneContacts(CallEvent event) async {
    try {
      final saved = await PhoneContactService().findByPhoneNumber(event.phoneNumber);
      final name = saved?.displayName.trim() ?? '';
      if (name.isEmpty) return null;
      final id = await _contactRepo.insert(
        Contact(id: '', name: name, phoneNumber: event.phoneNumber, lastInteraction: event.timestamp),
      );
      AppLog.d(_tag, 'added $id from the phone contacts');
      return _contactRepo.getById(id);
    } catch (e) {
      AppLog.w(_tag, 'phone contacts unavailable', e);
      return null;
    }
  }

  /// A call with a number that isn't one of your people: it goes to New
  /// numbers (never into People on its own), with "Who was this?" after a
  /// real talk. Ignored numbers are kept quietly. Returns null: no contact.
  Future<Contact?> _logNewNumber(CallEvent event) async {
    final repo = NewNumberRepository();
    final shown = await repo.logCall(
      phoneNumber: event.phoneNumber,
      type: event.type,
      duration: event.duration,
      timestamp: event.timestamp,
    );
    final key = PhoneContact.matchKey(event.phoneNumber);
    // Something typed in the call card stays with the number until it's saved.
    final pending = await CallOverlayState.peekPendingReview();
    if (pending != null && pending['contactId'] == null) {
      final text = (pending['text'] as String? ?? '').trim();
      await CallOverlayState.takePendingReview();
      if (shown && text.isNotEmpty) await repo.saveNote(key, text);
    }
    if (!shown) {
      AppLog.d(_tag, 'ignored number, nothing to show');
      return null;
    }
    AppLog.d(_tag, 'logged ${event.type.name} call from a new number');
    final ask = shouldAskWhoWasThis(
      promptEnabled: await _settings.getPromptAfterCall(),
      type: event.type,
      duration: event.duration,
      minDuration: Duration(seconds: await _settings.getMinCallDuration()),
    );
    if (ask) {
      await NotificationService().showNewNumberPrompt(
        phoneNumber: event.phoneNumber,
        phoneKey: key,
        duration: event.duration,
      );
    }
    return null;
  }

  /// You talked to [contactId]: their call-back reminders are done and the
  /// missed-call notification goes away.
  Future<void> _closeCallBacks(String contactId) async {
    for (final reminder in await ReminderRepository().completeCallBacks(contactId)) {
      await NotificationService().cancelReminder(reminder.id);
    }
    await NotificationService().cancelMissedCallPrompt(contactId);
  }

  /// "Missed Selam · 10:42", unless missed-call notes are off in Settings.
  Future<void> _notifyMissed(Contact contact, CallEntry call) async {
    if (!await _settings.getMissedCallReminders()) return;
    final todos = await TodoRepository().getByContactId(contact.id);
    final owed = todos.where((t) => !t.isCompleted && t.owedBy == OwedBy.me).toList()
      ..sort((a, b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
    final open = callBacks(
      calls: await _callRepo.getByContactId(contact.id),
      contacts: {contact.id: contact},
      now: DateTime.now(),
    );
    final today = DateTime.now();
    final missedToday = open.isEmpty
        ? 1
        : (await _callRepo.getByContactId(contact.id))
              .where(
                (c) =>
                    c.type == CallType.missed &&
                    !c.timestamp.isBefore(open.first.firstMissedAt) &&
                    DayLabels.daysBetween(c.timestamp, today) == 0,
              )
              .length;
    await NotificationService().showMissedCallPrompt(
      contact,
      call,
      owe: owed.isEmpty ? '' : owed.first.title,
      missedToday: missedToday < 1 ? 1 : missedToday,
    );
  }
}
