class AiResult {
  final String summary;
  final List<String> actionItems;
  final String? reminderTitle;
  final DateTime? reminderDate;

  const AiResult({
    required this.summary,
    required this.actionItems,
    this.reminderTitle,
    this.reminderDate,
  });
}
