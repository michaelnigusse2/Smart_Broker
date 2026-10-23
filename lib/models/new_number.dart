import 'call_entry.dart';

/// A number that called (or that you called) and isn't one of your people
/// yet, with what happened: People → New numbers.
class NewNumber {
  const NewNumber({
    required this.phoneKey,
    required this.phoneNumber,
    required this.calls,
    required this.missed,
    required this.lastAt,
    this.lastMissedAt,
    this.lastTalkAt,
    this.lastTalk = Duration.zero,
    this.note = '',
  });

  /// [PhoneContact.matchKey] of the number: groups its calls.
  final String phoneKey;

  /// As the phone reported it, latest call first.
  final String phoneNumber;
  final int calls;
  final int missed;
  final DateTime lastAt;
  final DateTime? lastMissedAt;

  /// The last call where you actually talked, and how long.
  final DateTime? lastTalkAt;
  final Duration lastTalk;

  /// What you typed about them, moved to their notes when you save them.
  final String note;

  bool get talked => lastTalkAt != null;

  /// A missed call after your last talk: worth calling back.
  bool get waitingForCallBack => lastMissedAt != null && (lastTalkAt == null || lastMissedAt!.isAfter(lastTalkAt!));
}

/// One call row from a new number (`unassigned_calls`).
class NewNumberCall {
  const NewNumberCall({
    required this.id,
    required this.phoneNumber,
    required this.phoneKey,
    required this.type,
    required this.duration,
    required this.timestamp,
    this.note = '',
  });

  final String id;
  final String phoneNumber;
  final String phoneKey;
  final CallType type;
  final Duration duration;
  final DateTime timestamp;
  final String note;

  factory NewNumberCall.fromMap(Map<String, Object?> map) => NewNumberCall(
    id: map['id'] as String,
    phoneNumber: map['phoneNumber'] as String? ?? '',
    phoneKey: map['phoneKey'] as String? ?? '',
    type: CallType.values[(map['type'] as int).clamp(0, CallType.values.length - 1)],
    duration: Duration(seconds: map['duration'] as int? ?? 0),
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    note: map['note'] as String? ?? '',
  );
}

/// Groups calls (newest first) into new numbers, newest activity first.
List<NewNumber> groupNewNumbers(List<NewNumberCall> calls) {
  final byKey = <String, List<NewNumberCall>>{};
  for (final c in calls) {
    byKey.putIfAbsent(c.phoneKey, () => []).add(c);
  }
  final out = <NewNumber>[];
  for (final entry in byKey.entries) {
    final list = entry.value..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final missed = list.where((c) => c.type == CallType.missed).toList();
    final talks = list.where((c) => c.type != CallType.missed && c.duration > Duration.zero).toList();
    final note = list.map((c) => c.note.trim()).firstWhere((n) => n.isNotEmpty, orElse: () => '');
    out.add(
      NewNumber(
        phoneKey: entry.key,
        phoneNumber: list.first.phoneNumber,
        calls: list.length,
        missed: missed.length,
        lastAt: list.first.timestamp,
        lastMissedAt: missed.isEmpty ? null : missed.first.timestamp,
        lastTalkAt: talks.isEmpty ? null : talks.first.timestamp,
        lastTalk: talks.isEmpty ? Duration.zero : talks.first.duration,
        note: note,
      ),
    );
  }
  out.sort((a, b) => b.lastAt.compareTo(a.lastAt));
  return out;
}
