import 'call_entry.dart';

/// Lightweight DTO for raw call data from the native side (before contact matching).
class CallEvent {
  final String phoneNumber;
  final CallType type;
  final Duration duration;
  final DateTime timestamp;

  const CallEvent({
    required this.phoneNumber,
    required this.type,
    required this.duration,
    required this.timestamp,
  });

  factory CallEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'missed';
    final callType = switch (typeStr) {
      'incoming' => CallType.incoming,
      'outgoing' => CallType.outgoing,
      _ => CallType.missed,
    };

    return CallEvent(
      phoneNumber: map['phoneNumber'] as String? ?? '',
      type: callType,
      duration: Duration(seconds: (map['duration'] as int?) ?? 0),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
