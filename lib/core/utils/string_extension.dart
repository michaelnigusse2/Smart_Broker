extension StringExtension on String {
  /// "incoming" → "Incoming".
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
