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
}
