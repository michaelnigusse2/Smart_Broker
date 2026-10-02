class Reminder {
  final String id;
  final String contactId;
  final String? noteId; // NEW
  final String title;
  final String description; // NEW
  final DateTime dateTime;
  final bool completed; // NEW
  final DateTime createdAt; // NEW

  const Reminder({
    required this.id,
    required this.contactId,
    this.noteId, // NEW
    required this.title,
    this.description = '', // NEW
    required this.dateTime,
    this.completed = false, // NEW
    required this.createdAt, // NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contactId': contactId,
      'noteId': noteId,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'completed': completed ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      contactId: map['contactId'],
      noteId: map['noteId'],
      title: map['title'],
      description: map['description'] ?? '',
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      completed: map['completed'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  Reminder copyWith({
    String? id,
    String? contactId,
    String? noteId,
    String? title,
    String? description,
    DateTime? dateTime,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
