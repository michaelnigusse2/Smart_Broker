import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_broker/core/repositories/note_repository.dart';
import 'package:smart_broker/core/repositories/todo_repository.dart';
import 'package:smart_broker/core/services/profile_service.dart';
import 'package:smart_broker/core/theme/app_theme.dart';
import 'package:smart_broker/features/contacts/screens/contact_detail_screen.dart';
import 'package:smart_broker/features/contacts/screens/contacts_screen.dart';
import 'package:smart_broker/features/onboarding/screens/onboarding_screen.dart';
import 'package:smart_broker/features/today/screens/today_screen.dart';
import 'package:smart_broker/features/todos/screens/tasks_screen.dart';
import 'package:smart_broker/models/note.dart';
import 'package:smart_broker/models/todo_item.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

// Renders redesigned screens with the app's real fonts at the design boards'
// size (390 × 844) and saves them to build/design_snapshots/, so each screen
// can be laid next to its board on the "Espresso · final" canvas.
// Nothing is compared automatically: the pictures are for review.

const _board = Size(390, 844);
final _out = Directory('build/design_snapshots');

/// Loads every font the app declares (ours and the icon fonts) from the
/// asset manifest, so text and icons render as on the phone.
Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('board')));
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File('${_out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester tester, Widget screen, {Object? arguments}) async {
  tester.view.physicalSize = _board * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('board'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          // The boards show 24-hour times.
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
          // Route arguments reach screens such as the Person page as in the app.
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: arguments),
            builder: (_) => screen,
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
  // Two frames: the first builds the loaded screen, the second lets its
  // entrance animations finish.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

DateTime _tenPast10() => DateTime(2026, 10, 21, 10, 10);

Future<void> _seedBoardDay() async {
  final selam = await insertContact(
    id: 'c-selam',
    name: 'Selam Tesfaye',
    phone: '+251 911 000 001',
    company: 'Dashen Bank',
  );
  final dawit = await insertContact(id: 'c-dawit', name: 'Dawit Alemu', phone: '+251 911 000 002');
  final yonas = await insertContact(id: 'c-yonas', name: 'Yonas Bekele', phone: '+251 911 000 003');
  final hanna = await insertContact(id: 'c-hanna', name: 'Hanna Girma', phone: '+251 911 000 004');
  final lidet = await insertContact(id: 'c-lidet', name: 'ልደት መኮንን', phone: '+251 911 000 005');
  final meron = await insertContact(id: 'c-meron', name: 'Meron Haile', phone: '+251 911 000 006');
  await insertReminder(contactId: selam.id, at: DateTime(2026, 10, 21, 10, 30), title: 'Office lease');
  await insertReminder(contactId: dawit.id, at: DateTime(2026, 10, 21, 13), title: 'Supplier');
  await insertReminder(contactId: yonas.id, at: DateTime(2026, 10, 21, 16), title: 'Board prep');
  final todos = TodoRepository();
  await todos.insert(
    TodoItem(
      id: '',
      contactId: selam.id,
      title: 'numbers',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 21, 17),
    ),
  );
  await todos.insert(
    TodoItem(
      id: '',
      contactId: hanna.id,
      title: 'Contract draft',
      createdAt: DateTime(2026, 10, 15),
      dueAt: DateTime(2026, 10, 19),
    ),
  );
  await todos.insert(
    TodoItem(
      id: '',
      contactId: dawit.id,
      title: 'Payment terms',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 23),
    ),
  );
  await todos.insert(
    TodoItem(
      id: '',
      contactId: lidet.id,
      title: 'Office shortlist',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 28),
    ),
  );
  await todos.insert(
    TodoItem(
      id: '',
      contactId: meron.id,
      title: 'Site visit',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 30),
    ),
  );
  // Two notes from this morning's calls that still need wrapping up.
  for (final contact in [dawit, hanna]) {
    await NoteRepository().insert(
      Note(
        id: '',
        contactId: contact.id,
        rawText: 'Talked it through',
        aiSummary: '',
        createdAt: DateTime(2026, 10, 21, 9),
      ),
    );
  }
}

/// The people on the People board, with when you last talked and what's owed.
Future<void> _seedBoardPeople() async {
  final now = _tenPast10();
  var number = 100;
  Future<String> person(String id, String name, String company, Duration ago) async => (await insertContact(
    id: id,
    name: name,
    phone: '+251 911 000 ${number++}',
    company: company,
    lastInteraction: now.subtract(ago),
  )).id;
  await person('c-abebe', 'Abebe Kebede', 'Ethio Telecom', const Duration(days: 7));
  final dawit = await person('c-dawit', 'Dawit Alemu', 'Supplier', const Duration(hours: 1));
  final hanna = await person('c-hanna', 'Hanna Girma', 'Lawyer', const Duration(days: 2));
  await person('c-meron', 'Meron Haile', 'Investor', const Duration(days: 14));
  final selam = await person('c-selam', 'Selam Tesfaye', 'Dashen Bank', const Duration(days: 1));
  await person('c-yonas', 'Yonas Bekele', 'Board', const Duration(days: 3));
  final lidet = await person('c-lidet', 'ልደት መኮንን', '', const Duration(days: 20));
  final todos = TodoRepository();
  for (final (contactId, due) in [
    (hanna, DateTime(2026, 10, 19)),
    (selam, DateTime(2026, 10, 21, 17)),
    (dawit, DateTime(2026, 10, 23)),
    (lidet, DateTime(2026, 10, 26)),
  ]) {
    await todos.insert(
      TodoItem(id: '', contactId: contactId, title: 'Promise', createdAt: DateTime(2026, 10, 15), dueAt: due),
    );
  }
}

/// Selam as on the Person board: a promise each way and three talks.
Future<String> _seedBoardPerson() async {
  final selam = await insertContact(
    id: 'c-selam',
    name: 'Selam Tesfaye',
    phone: '+251 911 000 001',
    company: 'Dashen Bank',
  );
  final todos = TodoRepository();
  await todos.insert(
    TodoItem(
      id: '',
      contactId: selam.id,
      title: '3-year numbers',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 23, 23, 59),
    ),
  );
  await todos.insert(
    TodoItem(
      id: '',
      contactId: selam.id,
      title: 'Signed offer',
      createdAt: DateTime(2026, 10, 20),
      dueAt: DateTime(2026, 10, 26, 23, 59),
      owedBy: OwedBy.them,
    ),
  );
  for (final (summary, at) in [
    ('Wants 3-year term', DateTime(2026, 10, 20, 15)),
    ('Asked for 5% off', DateTime(2026, 10, 12, 11)),
    ('First meeting', DateTime(2026, 10, 3, 9)),
  ]) {
    await NoteRepository().insert(
      Note(id: '', contactId: selam.id, rawText: summary, aiSummary: summary, createdAt: at),
    );
  }
  return selam.id;
}

/// The promises on the Promises board: five you owe, three owed to you.
Future<void> _seedBoardPromises() async {
  var number = 200;
  Future<String> person(String id, String name) async =>
      (await insertContact(id: id, name: name, phone: '+251 911 000 ${number++}')).id;
  final hanna = await person('c-hanna', 'Hanna Girma');
  final dawit = await person('c-dawit', 'Dawit Alemu');
  final selam = await person('c-selam', 'Selam Tesfaye');
  final yonas = await person('c-yonas', 'Yonas Bekele');
  final lidet = await person('c-lidet', 'ልደት መኮንን');
  final abebe = await person('c-abebe', 'Abebe Kebede');
  final meron = await person('c-meron', 'Meron Haile');
  final todos = TodoRepository();
  for (final (contactId, title, due, owedBy) in [
    (hanna, 'Contract draft', DateTime(2026, 10, 19, 23, 59), OwedBy.me),
    (dawit, 'Payment terms', DateTime(2026, 10, 22, 23, 59), OwedBy.me),
    (selam, '3-year numbers', DateTime(2026, 10, 23, 23, 59), OwedBy.me),
    (yonas, 'Board deck', DateTime(2026, 10, 23, 23, 59), OwedBy.me),
    (lidet, 'Office shortlist', DateTime(2026, 10, 28, 23, 59), OwedBy.me),
    (selam, 'Signed offer', DateTime(2026, 10, 26, 23, 59), OwedBy.them),
    (abebe, 'Title deed copy', DateTime(2026, 10, 24, 23, 59), OwedBy.them),
    (meron, 'Budget sign-off', DateTime(2026, 11, 4, 23, 59), OwedBy.them),
  ]) {
    await todos.insert(
      TodoItem(
        id: '',
        contactId: contactId,
        title: title,
        createdAt: DateTime(2026, 10, 15),
        dueAt: due,
        owedBy: owedBy,
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useFreshTestDatabase();
  });
  tearDown(closeTestDatabase);

  testWidgets('Today, as on the board', (tester) async {
    await tester.runAsync(_seedBoardDay);
    await tester.runAsync(() => ProfileService().setName('Michael'));
    await _pump(tester, TodayScreen(clock: _tenPast10));
    await _snap(tester, 'today');
  });

  testWidgets('People, as on the board', (tester) async {
    await tester.runAsync(_seedBoardPeople);
    await _pump(tester, ContactsScreen(clock: _tenPast10));
    await _snap(tester, 'people');
  });

  testWidgets('Person, as on the board', (tester) async {
    final id = await tester.runAsync(_seedBoardPerson);
    await _pump(tester, ContactDetailScreen(clock: _tenPast10), arguments: id);
    await _snap(tester, 'person');
  });

  testWidgets('Promises, as on the board', (tester) async {
    await tester.runAsync(_seedBoardPromises);
    await _pump(tester, TasksScreen(clock: _tenPast10));
    await _snap(tester, 'promises');
  });

  testWidgets('Onboarding steps, as on the boards', (tester) async {
    await tester.runAsync(() async {
      await ProfileService().setName('Michael');
      await ProfileService().setWork(WorkType.company);
    });
    const names = ['welcome', 'name', 'work', 'setup', 'ready'];
    for (var step = 0; step < names.length; step++) {
      await _pump(tester, OnboardingScreen(key: ValueKey(step), initialStep: step));
      await _snap(tester, 'onboarding_${step + 1}_${names[step]}');
    }
  });
}
