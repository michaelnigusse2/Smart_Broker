import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/features/contacts/screens/contact_form_screen.dart';

void main() {
  test('name is required', () {
    expect(ContactFormScreen.validateName(''), isNotNull);
    expect(ContactFormScreen.validateName('   '), isNotNull);
    expect(ContactFormScreen.validateName('Hanna'), isNull);
  });

  test('phone needs at least 7 digits, any formatting', () {
    expect(ContactFormScreen.validatePhone(''), isNotNull);
    expect(ContactFormScreen.validatePhone('+251'), isNotNull);
    expect(ContactFormScreen.validatePhone('+251 911 000 001'), isNull);
    expect(ContactFormScreen.validatePhone('0911-000-001'), isNull);
  });

  test('email is optional but must look like one', () {
    expect(ContactFormScreen.validateEmail(''), isNull);
    expect(ContactFormScreen.validateEmail('hanna@example.com'), isNull);
    expect(ContactFormScreen.validateEmail('hanna@'), isNotNull);
    expect(ContactFormScreen.validateEmail('hanna example.com'), isNotNull);
  });
}
