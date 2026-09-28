

class UnifiedContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String company;
  final String role;
  final DateTime lastInteraction;
  final int pendingTasksCount;
  final String avatarUrl;
  
  /// True if this contact exists in the SmartBroker SQLite database.
  final bool isSmartBrokerContact;
  
  /// True if this contact exists in the device's native phone book.
  final bool isPhoneContact;

  UnifiedContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email = '',
    this.company = '',
    this.role = '',
    required this.lastInteraction,
    this.pendingTasksCount = 0,
    this.avatarUrl = '',
    required this.isSmartBrokerContact,
    required this.isPhoneContact,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedContact && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
