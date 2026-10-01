import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/models/call_event.dart';
import 'package:smart_broker/models/call_entry.dart';
import 'package:smart_broker/models/phone_contact.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // CallEvent.fromMap — parsing native Kotlin data into Dart objects
  // ═══════════════════════════════════════════════════════════════════
  group('CallEvent.fromMap', () {
    test('parses a complete incoming call event', () {
      final map = <dynamic, dynamic>{
        'phoneNumber': '+1 (555) 123-4567',
        'type': 'incoming',
        'duration': 125,
        'timestamp': 1721827200000, // Fixed timestamp
      };

      final event = CallEvent.fromMap(map);

      expect(event.phoneNumber, '+1 (555) 123-4567');
      expect(event.type, CallType.incoming);
      expect(event.duration, const Duration(seconds: 125));
      expect(event.timestamp, DateTime.fromMillisecondsSinceEpoch(1721827200000));
    });

    test('parses an outgoing call event', () {
      final map = <dynamic, dynamic>{
        'phoneNumber': '5551234567',
        'type': 'outgoing',
        'duration': 60,
        'timestamp': 1721827200000,
      };

      final event = CallEvent.fromMap(map);

      expect(event.type, CallType.outgoing);
      expect(event.duration, const Duration(seconds: 60));
    });

    test('parses a missed call (0 duration)', () {
      final map = <dynamic, dynamic>{
        'phoneNumber': '+821012345678',
        'type': 'missed',
        'duration': 0,
        'timestamp': 1721827200000,
      };

      final event = CallEvent.fromMap(map);

      expect(event.type, CallType.missed);
      expect(event.duration, Duration.zero);
    });

    test('handles missing fields gracefully', () {
      final map = <dynamic, dynamic>{};

      final event = CallEvent.fromMap(map);

      expect(event.phoneNumber, '');
      expect(event.type, CallType.missed); // default fallback
      expect(event.duration, Duration.zero);
    });

    test('handles unknown call type string as missed', () {
      final map = <dynamic, dynamic>{
        'phoneNumber': '1234567890',
        'type': 'rejected', // not a known type
        'duration': 5,
        'timestamp': 1721827200000,
      };

      final event = CallEvent.fromMap(map);

      expect(event.type, CallType.missed);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // PhoneContact.normalizePhoneNumber — the shared normalization logic
  // ═══════════════════════════════════════════════════════════════════
  group('PhoneContact.normalizePhoneNumber', () {
    test('strips spaces, dashes, and parentheses', () {
      expect(
        PhoneContact.normalizePhoneNumber('+1 (555) 123-4567'),
        '+15551234567',
      );
    });

    test('preserves leading + sign', () {
      expect(
        PhoneContact.normalizePhoneNumber('+821012345678'),
        '+821012345678',
      );
    });

    test('handles plain digits', () {
      expect(
        PhoneContact.normalizePhoneNumber('5551234567'),
        '5551234567',
      );
    });

    test('handles empty string', () {
      expect(
        PhoneContact.normalizePhoneNumber(''),
        '',
      );
    });

    test('strips dots and other separators', () {
      expect(
        PhoneContact.normalizePhoneNumber('555.123.4567'),
        '5551234567',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // CallEntry serialization — toMap / fromMap round-trip
  // ═══════════════════════════════════════════════════════════════════
  group('CallEntry serialization', () {
    test('toMap produces correct keys and types', () {
      final entry = CallEntry(
        id: 'call-001',
        contactId: 'contact-abc',
        type: CallType.incoming,
        duration: const Duration(seconds: 125),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1721827200000),
      );

      final map = entry.toMap();

      expect(map['id'], 'call-001');
      expect(map['contactId'], 'contact-abc');
      expect(map['type'], 0); // incoming = index 0
      expect(map['duration'], 125);
      expect(map['timestamp'], 1721827200000);
    });

    test('fromMap reconstructs the original object', () {
      final map = {
        'id': 'call-002',
        'contactId': 'contact-xyz',
        'type': 1, // outgoing
        'duration': 300,
        'timestamp': 1721827200000,
      };

      final entry = CallEntry.fromMap(map);

      expect(entry.id, 'call-002');
      expect(entry.contactId, 'contact-xyz');
      expect(entry.type, CallType.outgoing);
      expect(entry.duration, const Duration(seconds: 300));
      expect(entry.timestamp, DateTime.fromMillisecondsSinceEpoch(1721827200000));
    });

    test('round-trip: toMap → fromMap preserves all fields', () {
      final original = CallEntry(
        id: 'call-rt',
        contactId: 'contact-rt',
        type: CallType.missed,
        duration: Duration.zero,
        timestamp: DateTime(2026, 7, 24, 15, 0),
      );

      final roundTripped = CallEntry.fromMap(original.toMap());

      expect(roundTripped.id, original.id);
      expect(roundTripped.contactId, original.contactId);
      expect(roundTripped.type, original.type);
      expect(roundTripped.duration, original.duration);
      expect(roundTripped.timestamp, original.timestamp);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // CallEntry.copyWith
  // ═══════════════════════════════════════════════════════════════════
  group('CallEntry.copyWith', () {
    final base = CallEntry(
      id: 'c1',
      contactId: 'ct1',
      type: CallType.incoming,
      duration: const Duration(seconds: 30),
      timestamp: DateTime(2026, 7, 24),
    );

    test('returns identical object when no args', () {
      final copy = base.copyWith();

      expect(copy.id, base.id);
      expect(copy.contactId, base.contactId);
      expect(copy.type, base.type);
      expect(copy.duration, base.duration);
      expect(copy.timestamp, base.timestamp);
    });

    test('overrides only specified fields', () {
      final copy = base.copyWith(
        type: CallType.outgoing,
        duration: const Duration(seconds: 120),
      );

      expect(copy.id, base.id); // unchanged
      expect(copy.contactId, base.contactId); // unchanged
      expect(copy.type, CallType.outgoing); // changed
      expect(copy.duration, const Duration(seconds: 120)); // changed
      expect(copy.timestamp, base.timestamp); // unchanged
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // PhoneContact.numbersMatch — local vs international formats
  // ═══════════════════════════════════════════════════════════════════
  group('PhoneContact.numbersMatch', () {
    test('matches Ethiopian local and international formats', () {
      expect(PhoneContact.numbersMatch('0911 23 45 67', '+251 911 234 567'), isTrue);
      expect(PhoneContact.numbersMatch('251911234567', '0911234567'), isTrue);
    });

    test('does not match different numbers', () {
      expect(PhoneContact.numbersMatch('0911234567', '0911234568'), isFalse);
    });

    test('compares short codes in full', () {
      expect(PhoneContact.numbersMatch('8294', '8294'), isTrue);
      expect(PhoneContact.numbersMatch('8294', '994'), isFalse);
    });

    test('empty numbers never match', () {
      expect(PhoneContact.numbersMatch('', ''), isFalse);
    });
  });
}
