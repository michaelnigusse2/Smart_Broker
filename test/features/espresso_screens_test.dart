import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_broker/core/repositories/todo_repository.dart';
import 'package:smart_broker/core/services/profile_service.dart';
import 'package:smart_broker/core/theme/app_theme.dart';
import 'package:smart_broker/features/home/screens/main_shell.dart';
import 'package:smart_broker/features/onboarding/screens/onboarding_screen.dart';
import 'package:smart_broker/features/today/screens/today_screen.dart';
import 'package:smart_broker/models/todo_item.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

// The redesigned screens on a small phone with large text, in the real theme.
// Any overflow is reported by Flutter as an exception and fails the test.

const _phone = Size(360, 640);

Future<void> _pump(WidgetTester tester, Widget screen, {double textScale = 1.3}) async {
  tester.view.physicalSize = _phone * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump(const Duration(seconds: 1));
}

/// 10:10 on a Wednesday, like the mockups.
DateTime _tenPast10() => DateTime(2026, 10, 21, 10, 10);

Future<void> _seedDay() async {
  final selam = await insertContact(id: 'c-selam', name: 'Selam Tesfaye', phone: '+251 911 000 001');
  final dawit = await insertContact(id: 'c-dawit', name: 'Dawit Alemu', phone: '+251 911 000 002');
  final hanna = await insertContact(id: 'c-hanna', name: 'Hanna Girma Woldemariam', phone: '+251 911 000 003');
  await insertReminder(contactId: selam.id, at: DateTime(2026, 10, 21, 9), title: 'Morning check-in');
  await insertReminder(
    contactId: selam.id,
    at: DateTime(2026, 10, 21, 10, 30),
    title: 'Call about the office lease and the three-year term',
  );
  await insertReminder(contactId: dawit.id, at: DateTime(2026, 10, 21, 13), title: 'Meeting at his office');
  await insertReminder(contactId: hanna.id, at: DateTime(2026, 10, 19, 16), title: 'Contract draft');
  await TodoRepository().insert(
    TodoItem(
      id: '',
      contactId: selam.id,
      title: 'Send the revised three-year numbers',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 21, 17),
    ),
  );
  await TodoRepository().insert(
    TodoItem(
      id: '',
      contactId: hanna.id,
      title: 'Contract draft',
      createdAt: DateTime(2026, 10, 15),
      dueAt: DateTime(2026, 10, 19),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useFreshTestDatabase();
  });
  tearDown(closeTestDatabase);

  testWidgets('Today shows the day, the next call and who is waiting', (tester) async {
    await tester.runAsync(_seedDay);
    await tester.runAsync(() => ProfileService().setName('Michael'));
    await _pump(tester, TodayScreen(clock: _tenPast10));

    expect(find.textContaining('ጥቅምት 11'), findsOneWidget);
    // What's left of the day: the 10:30 call and the 13:00 meeting.
    expect(find.textContaining('2 calls today.'), findsOneWidget);
    // Only Selam's promise falls due today; Hanna's is from Monday, so it
    // shows as late under "Waiting on you" instead.
    expect(find.textContaining('1 promise due.'), findsOneWidget);
    // As on the board: "Now" heads the list, past items aren't listed.
    expect(find.text('Now'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Now')).dy, lessThan(tester.getTopLeft(find.text('20 min')).dy));
    expect(find.text('Morning check-in'), findsNothing);
    expect(find.text('Late'), findsNothing);
    // The 10:30 call is next: opened up with what's owed and a Call button.
    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('You owe: Send the revised three-year numbers'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Waiting on you'), 200);
    expect(find.text('Waiting on you'), findsOneWidget);
    // Hanna's promise is overdue. Selam is left out: she is opened up at the
    // top of the agenda with what's owed already.
    expect(find.text('1 late'), findsOneWidget);
  });

  testWidgets('Today with nothing planned', (tester) async {
    await _pump(tester, TodayScreen(clock: _tenPast10));

    expect(find.textContaining('A clear day.'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);
    expect(find.text('Waiting on you'), findsNothing);
  });

  testWidgets('The shell has four tabs and the capture button', (tester) async {
    await _pump(tester, const MainShell());

    for (final tab in ['Today', 'People', 'Promises', 'Deals']) {
      expect(find.bySemanticsLabel(tab), findsWidgets);
    }
    expect(find.bySemanticsLabel('Add a note'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Deals'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Your deals will live here'), findsOneWidget);
  });

  testWidgets('Onboarding walks from hello to the setup step', (tester) async {
    await _pump(tester, const OnboardingScreen());

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.textContaining('What should we'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Michael');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Continue'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Michael.'), findsOneWidget);
    expect(await tester.runAsync(() => ProfileService().getName()), 'Michael');

    await tester.ensureVisible(find.text('Real estate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Real estate'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Continue'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Offline voice'), findsOneWidget);
    expect(await tester.runAsync(() => ProfileService().getWork()), WorkType.realEstate);
  });
}
