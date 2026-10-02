class TodoItem {
  final String id;
  final String contactId;
  final String? noteId; // NEW — links to the note that generated this todo
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt; // NEW

  const TodoItem({
    required this.id,
    required this.contactId,
    this.noteId, // NEW
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt, // NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contactId': contactId,
      'noteId': noteId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'],
      contactId: map['contactId'],
      noteId: map['noteId'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt: map['completedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['completedAt']) : null,
    );
  }

  TodoItem copyWith({
    String? id,
    String? contactId,
    String? noteId,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TodoItem(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      noteId: noteId ?? this.noteId,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
