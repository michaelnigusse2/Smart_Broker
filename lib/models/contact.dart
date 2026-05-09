class Contact {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String company;
  final String role;
  final DateTime lastInteraction;
  final int pendingTasksCount;
  final String avatarUrl; // Optional mock image URL

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
}
