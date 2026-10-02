import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/features/contacts/screens/contact_detail_screen.dart';

void main() {
  test('capitalize', () {
    expect(''.capitalize(), '');
    expect('incoming'.capitalize(), 'Incoming');
    expect('x'.capitalize(), 'X');
  });
}
