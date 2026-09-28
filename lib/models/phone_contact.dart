class PhoneContact {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? photoUrl;

  PhoneContact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.photoUrl,
  });

  /// Normalizes the phone number by removing spaces, dashes, parentheses.
  /// For now, we strip everything except digits and a leading '+' sign.
  String get normalizedNumber {
    return normalizePhoneNumber(phoneNumber);
  }

  static String normalizePhoneNumber(String raw) {
    if (raw.isEmpty) return '';
    // Keep '+' if it's the first character, otherwise remove all non-digits
    final hasPlus = raw.startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }
}
