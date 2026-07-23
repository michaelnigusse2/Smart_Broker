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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contactId': contactId,
      'type': type.index, // Store as integer (0=incoming, 1=outgoing, 2=missed)
      'duration': duration.inSeconds, // Store as integer seconds
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory CallEntry.fromMap(Map<String, dynamic> map) {
    return CallEntry(
      id: map['id'],
      contactId: map['contactId'],
      type: CallType.values[map['type']],
      duration: Duration(seconds: map['duration']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  CallEntry copyWith({
    String? id,
    String? contactId,
    CallType? type,
    Duration? duration,
    DateTime? timestamp,
  }) {
    return CallEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
