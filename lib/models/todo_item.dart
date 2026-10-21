/// Who has to deliver a promise: you (the default), or the other person.
enum OwedBy {
  me,
  them
  ;

  static OwedBy fromName(Object? name) => name == 'them' ? OwedBy.them : OwedBy.me;
}

class TodoItem {
  final String id;
  final String contactId;
  final String? noteId; // NEW — links to the note that generated this todo
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt; // NEW

  /// When the task is due (date and time), if it has a due date.
  final DateTime? dueAt;

  /// You owe it to them, or they owe it to you.
  final OwedBy owedBy;

  const TodoItem({
    required this.id,
    required this.contactId,
    this.noteId, // NEW
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt, // NEW
    this.dueAt,
    this.owedBy = OwedBy.me,
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
      'dueAt': dueAt?.millisecondsSinceEpoch,
      'owedBy': owedBy.name,
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
      dueAt: map['dueAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dueAt'] as int) : null,
      owedBy: OwedBy.fromName(map['owedBy']),
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
    DateTime? dueAt,
    bool clearDueAt = false,
    OwedBy? owedBy,
  }) {
    return TodoItem(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      noteId: noteId ?? this.noteId,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      owedBy: owedBy ?? this.owedBy,
    );
  }
}
