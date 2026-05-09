enum CallType {
  incoming,
  outgoing,
  missed,
}

class CallEntry {
  final String id;
  final String contactId;
  final CallType type;
  final Duration duration;
  final DateTime timestamp;

  const CallEntry({
    required this.id,
    required this.contactId,
    required this.type,
    required this.duration,
    required this.timestamp,
  });
}
