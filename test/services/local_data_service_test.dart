import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/core/repositories/reminder_repository.dart';
import 'package:smart_broker/core/services/local_data_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  setUp(useFreshTestDatabase);
  tearDown(closeTestDatabase);

  test('reset cancels reminder alarms and leaves an empty, usable database', () async {
    final contact = await insertContact();
    final reminder = await insertReminder(contactId: contact.id, at: DateTime.now().add(const Duration(days: 1)));
    final cancelled = <String>[];
    var callStateCleared = false;

    await LocalDataService(
      cancelReminder: (id) async => cancelled.add(id),
      clearCallState: () async => callStateCleared = true,
    ).resetAll();

    expect(cancelled, [reminder.id]);
    expect(callStateCleared, isTrue);
    expect(await ContactRepository().getAll(), isEmpty);
    expect(await ReminderRepository().getAll(), isEmpty);

    await insertContact(id: 'after-reset');
    expect(await ContactRepository().getAll(), hasLength(1));
  });
}
