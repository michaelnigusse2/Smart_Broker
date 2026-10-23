import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_broker/core/repositories/call_repository.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/core/repositories/new_number_repository.dart';
import 'package:smart_broker/core/theme/app_theme.dart';
import 'package:smart_broker/features/contacts/screens/contact_detail_screen.dart';
import 'package:smart_broker/features/contacts/screens/contact_form_screen.dart';
import 'package:smart_broker/features/contacts/screens/contacts_screen.dart';
import 'package:smart_broker/features/today/screens/today_screen.dart';
import 'package:smart_broker/models/call_entry.dart';
import 'package:smart_broker/models/reminder.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

// Missed calls → Call back, and new numbers, on Today, Person, People and
// the person form. Small phone, large text, Ink theme: overflow fails.

const _phone = Size(360, 640);

/// 10:10 on a Wednesday, like the mockups.
DateTime _tenPast10() => DateTime(2026, 10, 21, 10, 10);

Future<void> _pump(WidgetTester tester, {Widget? home, RouteFactory? routes}) async {
  tester.view.physicalSize = _phone * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(AppThemeName.ink), home: home, onGenerateRoute: routes),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  // One frame starts the rise-in animations, the next finishes them.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// Selam called twice this morning and you haven't talked since.
Future<void> _seedMissed() async {
  final selam = await insertContact(id: 'c-selam', name: 'Selam Tesfaye', phone: '+251 911 000 001');
  await insertCall(
    contactId: selam.id,
    type: CallType.incoming,
    at: DateTime(2026, 10, 20, 15),
    duration: const Duration(minutes: 4),
  );
  await insertCall(contactId: selam.id, type: CallType.missed, at: DateTime(2026, 10, 21, 9, 58));
  await insertCall(contactId: selam.id, type: CallType.missed, at: DateTime(2026, 10, 21, 10, 5));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useFreshTestDatabase();
  });
  tearDown(closeTestDatabase);

  testWidgets('Today leads with who to call back', (tester) async {
    await tester.runAsync(() async {
      await _seedMissed();
      await insertReminder(
        contactId: 'c-selam',
        at: DateTime(2026, 10, 21, 18),
        title: 'Call Selam back',
        kind: Reminder.callBack,
      );
      await NewNumberRepository().logCall(
        phoneNumber: '+251 930 555 702',
        type: CallType.missed,
        duration: Duration.zero,
        timestamp: DateTime(2026, 10, 21, 9, 12),
      );
    });
    await _pump(tester, home: TodayScreen(clock: _tenPast10));

    expect(find.textContaining('1 to call back.'), findsOneWidget);
    expect(find.text('Call back'), findsOneWidget);
    expect(find.textContaining('Missed 2 calls · 10:05'), findsOneWidget);
    // The call back reminder rides on the row, not in the agenda.
    expect(find.text('Reminder 18:00'), findsOneWidget);
    expect(find.text('Call Selam back'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Call Selam back'), findsOneWidget);
    expect(find.text('New number · missed 09:12'), findsOneWidget);
  });

  testWidgets('A talk closes the call back', (tester) async {
    await tester.runAsync(() async {
      await _seedMissed();
      await insertCall(
        contactId: 'c-selam',
        type: CallType.outgoing,
        at: DateTime(2026, 10, 21, 10, 8),
        duration: const Duration(minutes: 2),
      );
    });
    await _pump(tester, home: TodayScreen(clock: _tenPast10));

    expect(find.textContaining('to call back.'), findsNothing);
    expect(find.text('Call back'), findsNothing);
  });

  testWidgets('Person shows the missed calls, and Not needed clears them', (tester) async {
    await tester.runAsync(_seedMissed);
    await _pump(
      tester,
      routes: (settings) => MaterialPageRoute(
        settings: const RouteSettings(name: '/', arguments: 'c-selam'),
        builder: (_) => ContactDetailScreen(clock: _tenPast10),
      ),
    );

    expect(find.text('Selam called twice'), findsOneWidget);
    expect(find.text('Missed 09:58 and 10:05'), findsOneWidget);
    expect(find.text('Call back'), findsOneWidget);
    expect(find.text('Missed · 2 calls'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Not needed'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Selam called twice'), findsNothing);
    expect(find.text('Call'), findsOneWidget);
    final selam = await tester.runAsync(() => ContactRepository().getById('c-selam'));
    expect(selam!.callBackClearedAt, isNotNull);
  });

  testWidgets('People lists new numbers and who to call back first', (tester) async {
    await tester.runAsync(() async {
      await _seedMissed();
      await NewNumberRepository().logCall(
        phoneNumber: '+251 944 103 321',
        type: CallType.incoming,
        duration: const Duration(seconds: 48),
        timestamp: DateTime(2026, 10, 19, 11),
      );
    });
    await _pump(tester, home: ContactsScreen(clock: _tenPast10));

    expect(find.textContaining('New numbers'), findsOneWidget);
    expect(find.text('+251 944 103 321'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Waiting on you'), 200);
    expect(find.text('Call back'), findsOneWidget);
  });

  testWidgets('The person form saves a second number and takes its calls', (tester) async {
    await tester.runAsync(() async {
      await NewNumberRepository().logCall(
        phoneNumber: '+251 922 000 009',
        type: CallType.incoming,
        duration: const Duration(minutes: 3),
        timestamp: DateTime(2026, 10, 20, 12),
      );
    });
    Object? popped;
    await _pump(
      tester,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => popped = await Navigator.push<Object?>(
            context,
            MaterialPageRoute<Object?>(builder: (_) => const ContactFormScreen()),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New person'), findsOneWidget);
    expect(find.text('From phone contacts'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Abebe Girma');
    await tester.enterText(find.byType(TextFormField).at(1), '+251 911 000 007');
    await tester.tap(find.text('Add another number'));
    await tester.pumpAndSettle();
    expect(find.text('Second phone'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '0922 000 009');

    await tester.runAsync(() async {
      await tester.tap(find.text('Add person'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(popped, isA<String>());
    final saved = await tester.runAsync(() => ContactRepository().getById(popped! as String));
    expect(saved!.name, 'Abebe Girma');
    expect(saved.otherPhones, ['0922000009']);
    expect((await tester.runAsync(() => ContactRepository().findByPhone('+251922000009')))!.id, saved.id);
    final calls = await tester.runAsync(() => CallRepository().getByContactId(saved.id));
    expect(calls, hasLength(1));
    expect(await tester.runAsync(() => NewNumberRepository().find('922000009')), isNull);
  });

  testWidgets('The person form refuses a number that is someone else\'s', (tester) async {
    await tester.runAsync(() => insertContact(id: 'c-dawit', name: 'Dawit Alemu', phone: '+251 911 000 002'));
    final dawit = await tester.runAsync(() => ContactRepository().getById('c-dawit'));
    await tester.runAsync(() => insertContact(id: 'c-hanna', name: 'Hanna Girma', phone: '+251 911 000 003'));
    final hanna = await tester.runAsync(() => ContactRepository().getById('c-hanna'));
    await _pump(
      tester,
      routes: (settings) => MaterialPageRoute(
        settings: RouteSettings(name: '/', arguments: hanna),
        builder: (_) => const ContactFormScreen(),
      ),
    );
    expect(find.text('Edit person'), findsOneWidget);
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Delete Hanna'), 200, scrollable: list);
    expect(find.text('Delete Hanna'), findsOneWidget);

    await tester.ensureVisible(find.text('Add another number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), dawit!.phoneNumber);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Already saved for Dawit Alemu'), findsOneWidget);
    final still = await tester.runAsync(() => ContactRepository().getById('c-hanna'));
    expect(still!.otherPhones, isEmpty);
  });

  test('form validators', () {
    expect(ContactFormScreen.validateOtherPhone(''), isNull);
    expect(ContactFormScreen.validateOtherPhone('   '), isNull);
    expect(ContactFormScreen.validateOtherPhone('0911'), isNotNull);
    expect(ContactFormScreen.validateOtherPhone('0911 000 001'), isNull);
    expect(ContactFormScreen.phoneLabel(0), 'Mobile');
    expect(ContactFormScreen.phoneLabel(1), 'Second phone');
    expect(ContactFormScreen.phoneLabel(4), 'Another phone');
  });
}
