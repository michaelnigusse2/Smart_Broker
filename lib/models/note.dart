class Note {
  final String id;
  final String contactId;
  final String rawText;
  final String aiSummary;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.contactId,
    required this.rawText,
    required this.aiSummary,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contactId': contactId,
      'rawText': rawText,
      'aiSummary': aiSummary,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      contactId: map['contactId'],
      rawText: map['rawText'],
      aiSummary: map['aiSummary'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  Note copyWith({
    String? id,
    String? contactId,
    String? rawText,
    String? aiSummary,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      rawText: rawText ?? this.rawText,
      aiSummary: aiSummary ?? this.aiSummary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
