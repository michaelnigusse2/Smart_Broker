import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/utils/phone_format.dart';

void main() {
  test('Ethiopian numbers are grouped for reading', () {
    expect(prettyPhone('+251930555702'), '+251 930 555 702');
    expect(prettyPhone('+251 911 77 21 04'), '+251 911 772 104');
    expect(prettyPhone('0930555702'), '0930 555 702');
  });

  test('anything else is left as given', () {
    expect(prettyPhone('+1 (555) 444-5555'), '+1 (555) 444-5555');
    expect(prettyPhone('8888'), '8888');
    expect(prettyPhone(''), '');
  });
}
