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

  /// Key used to decide whether two numbers belong to the same person.
  ///
  /// Uses the last 9 digits so local and international formats match —
  /// e.g. `0911 23 45 67` and `+251 911 234 567` both give `911234567`.
  /// Shorter numbers (service codes) are compared in full.
  static String matchKey(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > 9 ? digits.substring(digits.length - 9) : digits;
  }

  static bool numbersMatch(String a, String b) {
    final ka = matchKey(a);
    return ka.isNotEmpty && ka == matchKey(b);
  }
}
