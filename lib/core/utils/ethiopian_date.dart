/// A date in the Ethiopian calendar (Amete Mihret).
class EthiopianDate {
  const EthiopianDate(this.year, this.month, this.day);

  final int year;

  /// 1 = መስከረም … 12 = ነሐሴ, 13 = ጳጉሜ (the five- or six-day month).
  final int month;
  final int day;

  static const monthNames = [
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ',
  ];

  String get monthName => monthNames[month - 1];

  /// "ጥቅምት 11"
  String get shortLabel => '$monthName $day';

  /// "ጥቅምት 2019"
  String get monthYearLabel => '$monthName $year';

  static const _epochOffset = 1723856;

  /// Converts a Gregorian date (its year, month and day; the time is ignored).
  factory EthiopianDate.fromGregorian(DateTime date) {
    final jdn = _julianDayNumber(date.year, date.month, date.day);
    final r = (jdn - _epochOffset) % 1461;
    final n = (r % 365) + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - _epochOffset) ~/ 1461) + r ~/ 365 - r ~/ 1460;
    return EthiopianDate(year, n ~/ 30 + 1, n % 30 + 1);
  }

  static int _julianDayNumber(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  }

  @override
  bool operator ==(Object other) =>
      other is EthiopianDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}
