/// A number as people read it: "+251930555702" → "+251 930 555 702",
/// "0930555702" → "0930 555 702". Anything else is shown as given.
String prettyPhone(String raw) {
  final s = raw.trim();
  final digits = s.replaceAll(RegExp(r'\D'), '');
  if (s.startsWith('+251') && digits.length == 12) {
    return '+251 ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
  }
  if (!s.startsWith('+') && digits.length == 10 && digits.startsWith('0')) {
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
  }
  return s;
}
