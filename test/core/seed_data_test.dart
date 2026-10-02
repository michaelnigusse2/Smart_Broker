import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/database/seed_data.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/models/phone_contact.dart';
import 'package:smart_broker/mock/mock_contacts.dart';

import '../helpers/test_db.dart';

void main() {
  setUp(useFreshTestDatabase);
  tearDown(closeTestDatabase);

  test('release builds start with an empty database', () async {
    await SeedData.seedIfNeeded(seedDemoData: false);

    expect(await ContactRepository().getAll(), isEmpty);
  });

  test('debug builds seed an empty database once', () async {
    await SeedData.seedIfNeeded(seedDemoData: true);
    await SeedData.seedIfNeeded(seedDemoData: true);

    expect(await ContactRepository().getAll(), hasLength(mockContacts.length));
  });

  test('loadDemoData refuses to load twice', () async {
    expect(await SeedData.loadDemoData(), isTrue);
    expect(await SeedData.loadDemoData(), isFalse);
    expect(await ContactRepository().getAll(), hasLength(mockContacts.length));
  });

  test('demo contacts are fictional and have distinct numbers', () {
    final keys = mockContacts.map((c) => PhoneContact.matchKey(c.phoneNumber)).toSet();
    expect(keys, hasLength(mockContacts.length));
    for (final c in mockContacts) {
      expect(c.email.isEmpty || c.email.endsWith('@example.com'), isTrue, reason: c.email);
    }
  });
}
