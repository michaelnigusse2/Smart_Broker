import '../models/call_entry.dart';

final mockCalls = [
  CallEntry(
    id: 'cal1',
    contactId: 'c1',
    type: CallType.outgoing,
    duration: const Duration(minutes: 15, seconds: 30),
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  CallEntry(
    id: 'cal2',
    contactId: 'c1',
    type: CallType.incoming,
    duration: const Duration(minutes: 5, seconds: 12),
    timestamp: DateTime.now().subtract(const Duration(days: 14)),
  ),
  CallEntry(
    id: 'cal3',
    contactId: 'c2',
    type: CallType.missed,
    duration: const Duration(seconds: 0),
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  CallEntry(
    id: 'cal4',
    contactId: 'c2',
    type: CallType.outgoing,
    duration: const Duration(minutes: 8, seconds: 45),
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
  ),
  CallEntry(
    id: 'cal5',
    contactId: 'c3',
    type: CallType.incoming,
    duration: const Duration(minutes: 22, seconds: 10),
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
  ),
  CallEntry(
    id: 'cal6',
    contactId: 'c7',
    type: CallType.incoming,
    duration: const Duration(minutes: 2, seconds: 5),
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];
