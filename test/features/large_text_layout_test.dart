import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/repositories/call_repository.dart';
import 'package:smart_broker/core/repositories/note_repository.dart';
import 'package:smart_broker/features/calendar/screens/calendar_screen.dart';
import 'package:smart_broker/features/contacts/screens/contact_detail_screen.dart';
import 'package:smart_broker/features/contacts/screens/contacts_screen.dart';
import 'package:smart_broker/features/home/screens/home_screen.dart';
import 'package:smart_broker/models/call_entry.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

// Layout checks for small phones with large text. Any overflow ("RIGHT
// OVERFLOWED BY 24 PIXELS") is reported by Flutter as an exception, which
// fails the test with the full report (widget and source line).
//
// The test font draws every letter as a full square, so text is about twice
// as wide as with a real font: scale 1.3 here is harsher than the largest
// Android text size, which is the point.

const _phone = Size(360, 640); // dp: a small Android phone

Future<void> _pumpScreen(WidgetTester tester, Widget screen, {Object? arguments, double textScale = 1.3}) async {
  tester.view.physicalSize = _phone * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // The screens load from SQLite (real async), so let the queries finish
  // outside the fake clock before laying out the result.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        // Route arguments reach screens such as Contact Details the same way as in the app.
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: arguments),
          builder: (_) => screen,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump();
}

Future<String> _seed() async {
  final today = DateTime.now();
  final noon = DateTime(today.year, today.month, today.day, 12);
  final contact = await insertContact(name: 'Alemayehu Gebremedhin Tesfaye', phone: '+251 911 000 001');
  await NoteRepository().saveNote(
    contactId: contact.id,
    rawText: 'Wants a three-bedroom flat near Bole, budget about 9 million birr, can view on Saturday.',
  );
  await CallRepository().insert(
    CallEntry(
      id: '',
      contactId: contact.id,
      type: CallType.outgoing,
      duration: const Duration(minutes: 15),
      timestamp: noon.subtract(const Duration(days: 1)),
    ),
  );
  await insertTodo(contactId: contact.id, title: 'Send the revised floor plan and the payment schedule');
  await insertReminder(contactId: contact.id, at: noon, title: 'Call back about the three-bedroom unit near Bole');
  await insertReminder(contactId: contact.id, at: noon.add(const Duration(hours: 10)), title: 'Viewing');
  return contact.id;
}

void main() {
  setUp(useFreshTestDatabase);
  tearDown(closeTestDatabase);

  testWidgets('Calendar fits a small phone with large text', (tester) async {
    await tester.runAsync(_seed);
    await _pumpScreen(tester, const CalendarScreen());

    expect(find.text('Call back about the three-bedroom unit near Bole'), findsOneWidget);
  });

  testWidgets('Calendar week view fits a small phone with large text', (tester) async {
    await tester.runAsync(_seed);
    await _pumpScreen(tester, const CalendarScreen());

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
  });

  testWidgets('Home fits a small phone with large text', (tester) async {
    await tester.runAsync(_seed);
    await _pumpScreen(tester, const HomeScreen());

    expect(find.textContaining('Contacts'), findsWidgets);
  });

  testWidgets('Contact details fit a small phone with large text', (tester) async {
    final contactId = (await tester.runAsync(_seed))!;
    await _pumpScreen(tester, const ContactDetailScreen(), arguments: contactId);

    expect(find.text('Alemayehu Gebremedhin Tesfaye'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    expect(find.textContaining('three-bedroom flat'), findsOneWidget);
    // Call history lives behind More.
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call history'));
    await tester.pumpAndSettle();
    expect(find.text('Outgoing'), findsOneWidget);
  });

  testWidgets('Contacts list fits a small phone with large text', (tester) async {
    await tester.runAsync(_seed);
    await _pumpScreen(tester, const ContactsScreen());

    expect(find.text('Alemayehu Gebremedhin Tesfaye'), findsOneWidget);
  });
}
