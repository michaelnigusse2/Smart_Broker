import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/utils/ethiopian_date.dart';

void main() {
  test('new year falls on Meskerem 1', () {
    expect(EthiopianDate.fromGregorian(DateTime(2026, 9, 11)), const EthiopianDate(2019, 1, 1));
    // The year before a Gregorian leap year starts a day later.
    expect(EthiopianDate.fromGregorian(DateTime(2027, 9, 12)), const EthiopianDate(2020, 1, 1));
  });

  test('Christmas is Tahsas 29 and Timket is Tir 11', () {
    expect(EthiopianDate.fromGregorian(DateTime(2026, 1, 7)), const EthiopianDate(2018, 4, 29));
    expect(EthiopianDate.fromGregorian(DateTime(2026, 1, 19)), const EthiopianDate(2018, 5, 11));
  });

  test('Pagume holds the last days of the year', () {
    expect(EthiopianDate.fromGregorian(DateTime(2026, 9, 10)), const EthiopianDate(2018, 13, 5));
    expect(EthiopianDate.fromGregorian(DateTime(2027, 9, 11)), const EthiopianDate(2019, 13, 6));
  });

  test('labels use Amharic month names', () {
    final date = EthiopianDate.fromGregorian(DateTime(2026, 10, 21));
    expect(date.shortLabel, 'ጥቅምት 11');
    expect(date.monthYearLabel, 'ጥቅምት 2019');
  });
}
