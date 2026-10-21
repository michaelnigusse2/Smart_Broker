import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/utils/string_extension.dart';

void main() {
  test('capitalize', () {
    expect(''.capitalize(), '');
    expect('incoming'.capitalize(), 'Incoming');
    expect('x'.capitalize(), 'X');
  });
}
