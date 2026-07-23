class Contact {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String company;
  final String role;
  final DateTime lastInteraction;
  final int pendingTasksCount;
  final String avatarUrl;

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
  });

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
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
      'pendingTasksCount': pendingTasksCount,
      'avatarUrl': avatarUrl,
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
      pendingTasksCount: map['pendingTasksCount'] ?? 0,
      avatarUrl: map['avatarUrl'] ?? '',
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
    );
  }
}
