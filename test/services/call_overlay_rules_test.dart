import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/services/call_matching_service.dart';
import 'package:smart_broker/core/services/settings_service.dart';
import 'package:smart_broker/models/call_entry.dart';

void main() {
  group('shouldShowOverlay', () {
    bool show(OverlayMode mode, String phase, String? number, {bool known = false}) =>
        shouldShowOverlay(mode: mode, phase: phase, number: number, isKnownContact: known);

    test('knownOnly: contacts yes, unknown numbers no', () {
      expect(show(OverlayMode.knownOnly, 'ringing', '+251900000001', known: true), isTrue);
      expect(show(OverlayMode.knownOnly, 'ringing', '+251900000099'), isFalse);
      expect(show(OverlayMode.knownOnly, 'active', '+251900000099'), isFalse);
    });

    test('knownOnly: a ringing call waits for the number, an answered/outgoing one does not', () {
      expect(show(OverlayMode.knownOnly, 'ringing', null), isFalse);
      expect(show(OverlayMode.knownOnly, 'ringing', ''), isFalse);
      expect(show(OverlayMode.knownOnly, 'active', null), isTrue);
    });

    test('all and off ignore the caller', () {
      expect(show(OverlayMode.all, 'ringing', '+251900000099'), isTrue);
      expect(show(OverlayMode.all, 'ringing', null), isTrue);
      expect(show(OverlayMode.off, 'ringing', '+251900000001', known: true), isFalse);
    });
  });

  group('shouldPromptAfterCall', () {
    bool prompt({
      bool enabled = true,
      OverlayMode mode = OverlayMode.knownOnly,
      CallType type = CallType.incoming,
      int seconds = 60,
      bool known = true,
    }) => shouldPromptAfterCall(
      promptEnabled: enabled,
      mode: mode,
      type: type,
      duration: Duration(seconds: seconds),
      minDuration: const Duration(seconds: 10),
      isKnownContact: known,
    );

    test('known contact, long enough call', () => expect(prompt(), isTrue));
    test('setting off', () => expect(prompt(enabled: false), isFalse));
    test('missed call', () => expect(prompt(type: CallType.missed), isFalse));
    test('too short', () => expect(prompt(seconds: 9), isFalse));
    test('exactly the minimum', () => expect(prompt(seconds: 10), isTrue));
    test('unknown caller only in "all" mode', () {
      expect(prompt(known: false), isFalse);
      expect(prompt(known: false, mode: OverlayMode.off), isFalse);
      expect(prompt(known: false, mode: OverlayMode.all), isTrue);
    });
  });

  test('OverlayMode.byName', () {
    expect(OverlayMode.byName('all'), OverlayMode.all);
    expect(OverlayMode.byName('bogus'), isNull);
    expect(OverlayMode.byName(null), isNull);
  });

  test('marks on a call you placed are timed from when they picked up', () {
    final state = {
      'outgoing': true,
      'startedAt': 0,
      'endedAt': 100 * 1000, // 100 s from dialling to hanging up
      'marks': [
        {'type': 'mine', 'at': 40},
        {'type': 'theirs', 'at': 10}, // marked while it was still ringing
      ],
    };
    // The call log says they talked for 80 s, so it rang for 20.
    expect(talkTimeMarks(state, const Duration(seconds: 80)), [
      {'type': 'mine', 'at': 20},
      {'type': 'theirs', 'at': 0},
    ]);
    // Incoming calls are already timed from the answer.
    expect(talkTimeMarks({...state, 'outgoing': false}, const Duration(seconds: 80)).first['at'], 40);
  });
}
