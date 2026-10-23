import '../../models/call_entry.dart';
import '../../models/contact.dart';
import '../../models/reminder.dart';
import 'day_labels.dart';

/// Someone you missed and haven't talked to since: Today → Call back.
class CallBack {
  const CallBack({
    required this.contact,
    required this.missed,
    required this.firstMissedAt,
    required this.lastMissedAt,
    this.triedAt,
    this.reminder,
  });

  final Contact contact;

  /// Missed calls since you last talked.
  final int missed;
  final DateTime firstMissedAt;
  final DateTime lastMissedAt;

  /// You called back and nobody answered (the latest such call).
  final DateTime? triedAt;

  /// The "Remind me" reminder you set, if any.
  final Reminder? reminder;

  /// Not returned by the next day: it shows red, like a late promise.
  bool isLate(DateTime now) => DayLabels.daysBetween(firstMissedAt, now) >= 1;
}

/// How far back missed calls still ask for a call back.
const callBackWindow = Duration(days: 14);

/// Everyone to call back, newest missed call first.
///
/// A missed call stays open until you talk (you call and they answer, or
/// they call and you pick up) or you say "Not needed"
/// ([Contact.callBackClearedAt]). Calling back without an answer keeps it
/// open, marked as tried.
List<CallBack> callBacks({
  required Iterable<CallEntry> calls,
  required Map<String, Contact> contacts,
  Iterable<Reminder> reminders = const [],
  required DateTime now,
}) {
  final since = now.subtract(callBackWindow);
  final byContact = <String, List<CallEntry>>{};
  for (final call in calls) {
    if (call.timestamp.isBefore(since) || !contacts.containsKey(call.contactId)) continue;
    byContact.putIfAbsent(call.contactId, () => []).add(call);
  }
  final out = <CallBack>[];
  for (final MapEntry(key: id, value: list) in byContact.entries) {
    final contact = contacts[id]!;
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    DateTime? lastTalk;
    for (final c in list) {
      if (c.type != CallType.missed && c.duration > Duration.zero) lastTalk = c.timestamp;
    }
    final after = [lastTalk, contact.callBackClearedAt].whereType<DateTime>().fold<DateTime?>(
      null,
      (a, b) => a == null || b.isAfter(a) ? b : a,
    );
    final missed = [
      for (final c in list)
        if (c.type == CallType.missed && (after == null || c.timestamp.isAfter(after))) c,
    ];
    if (missed.isEmpty) continue;
    DateTime? tried;
    for (final c in list) {
      if (c.type == CallType.outgoing && c.duration == Duration.zero && c.timestamp.isAfter(missed.first.timestamp)) {
        tried = c.timestamp;
      }
    }
    final reminder = reminders
        .where((r) => r.isCallBack && !r.completed && r.contactId == id)
        .fold<Reminder?>(null, (a, r) => a == null || r.dateTime.isBefore(a.dateTime) ? r : a);
    out.add(
      CallBack(
        contact: contact,
        missed: missed.length,
        firstMissedAt: missed.first.timestamp,
        lastMissedAt: missed.last.timestamp,
        triedAt: tried,
        reminder: reminder,
      ),
    );
  }
  out.sort((a, b) => b.lastMissedAt.compareTo(a.lastMissedAt));
  return out;
}
