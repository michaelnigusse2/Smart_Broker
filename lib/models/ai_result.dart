class AiResult {
  final String summary;

  /// What the user has to do (you owe them).
  final List<String> actionItems;

  /// What the contact promised to do or send (they owe you).
  final List<String> theirItems;
  final String? reminderTitle;
  final DateTime? reminderDate;

  const AiResult({
    required this.summary,
    required this.actionItems,
    this.theirItems = const [],
    this.reminderTitle,
    this.reminderDate,
  });
}
