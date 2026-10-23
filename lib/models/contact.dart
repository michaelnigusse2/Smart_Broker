import 'phone_contact.dart';

class Contact {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String company;
  final String role;
  final DateTime lastInteraction;

  /// Open tasks for this contact. Computed by [ContactRepository] queries,
  /// never stored by the app (the old column is left unused).
  final int pendingTasksCount;
  final String avatarUrl;

  /// More numbers for the same person (a second phone), as typed.
  final List<String> otherPhones;

  /// When you said "Not needed" to their missed calls: calls missed before
  /// this don't ask for a call back.
  final DateTime? callBackClearedAt;

  const Contact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email = '',
    this.company = '',
    this.role = '',
    required this.lastInteraction,
    this.pendingTasksCount = 0,
    this.avatarUrl = '',
    this.otherPhones = const [],
    this.callBackClearedAt,
  });

  /// Every number: the main one first.
  List<String> get allPhones => [phoneNumber, ...otherPhones];

  /// Keys of [otherPhones], stored as ",key1,key2," so one LIKE finds them.
  String get otherPhoneKeys {
    final keys = [for (final p in otherPhones) PhoneContact.matchKey(p)].where((k) => k.isNotEmpty).toList();
    return keys.isEmpty ? '' : ',${keys.join(',')},';
  }

  /// Key that identifies this contact's number (see [PhoneContact.matchKey]).
  String get phoneKey => PhoneContact.matchKey(phoneNumber);

  String get initials {
    // Split on any whitespace and drop empty parts: "John ", "  Ann" or
    // "John  Smith" would otherwise index an empty string and crash.
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'company': company,
      'role': role,
      'lastInteraction': lastInteraction.millisecondsSinceEpoch,
      'avatarUrl': avatarUrl,
      'phoneKey': phoneKey,
      'otherPhones': otherPhones.join('\n'),
      'otherPhoneKeys': otherPhoneKeys,
      'callBackClearedAt': callBackClearedAt?.millisecondsSinceEpoch,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phoneNumber'],
      email: map['email'] ?? '',
      company: map['company'] ?? '',
      role: map['role'] ?? '',
      lastInteraction: DateTime.fromMillisecondsSinceEpoch(map['lastInteraction']),
      pendingTasksCount: (map['openTaskCount'] ?? map['pendingTasksCount'] ?? 0) as int,
      avatarUrl: map['avatarUrl'] ?? '',
      otherPhones: [
        for (final p in (map['otherPhones'] as String? ?? '').split('\n'))
          if (p.trim().isNotEmpty) p.trim(),
      ],
      callBackClearedAt: map['callBackClearedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['callBackClearedAt'] as int),
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? company,
    String? role,
    DateTime? lastInteraction,
    int? pendingTasksCount,
    String? avatarUrl,
    List<String>? otherPhones,
    DateTime? callBackClearedAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      company: company ?? this.company,
      role: role ?? this.role,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      pendingTasksCount: pendingTasksCount ?? this.pendingTasksCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      otherPhones: otherPhones ?? this.otherPhones,
      callBackClearedAt: callBackClearedAt ?? this.callBackClearedAt,
    );
  }
}
