class TodoItem {
  final String id;
  final String contactId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;

  const TodoItem({
    required this.id,
    required this.contactId,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
  });

  TodoItem copyWith({
    String? id,
    String? contactId,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
