import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'features/home/screens/main_shell.dart';
import 'features/contacts/screens/contact_detail_screen.dart';
import 'features/contacts/screens/phone_contact_detail_screen.dart';
import 'features/notes/screens/add_note_screen.dart';
import 'features/notes/screens/ai_review_screen.dart';
import 'features/notes/screens/note_detail_screen.dart';
import 'features/notes/screens/notes_list_screen.dart';

import 'features/calendar/screens/reminder_detail_screen.dart';

import 'core/database/seed_data.dart';
import 'core/services/notification_service.dart';

import 'features/todos/screens/tasks_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SeedData.seedIfNeeded();
  // Initialize and reschedule all upcoming reminder notifications
  await NotificationService().init();
  await NotificationService().rescheduleAll();

  FlutterOverlayWindow.overlayListener.listen((event) {
    if (event == null) return;
    try {
      final data = jsonDecode(event.toString());
      if (data['action'] == 'openAiReview') {
        AppRoutes.globalNavigatorKey.currentState?.pushNamed(
          AppRoutes.aiReview,
          arguments: {
            'contactId': data['contactId'],
            'rawText': data['noteText'],
          },
        );
      }
    } catch (e) {
      debugPrint('Error parsing overlay event in main: $e');
    }
  });

  runApp(const SmartBrokerApp());
}

class SmartBrokerApp extends StatelessWidget {
  const SmartBrokerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBroker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: AppRoutes.globalNavigatorKey,
      initialRoute: AppRoutes.shell,
      routes: {
        AppRoutes.shell: (context) => const MainShell(),
        AppRoutes.contactDetail: (context) => const ContactDetailScreen(),
        AppRoutes.noteDetail: (context) => const NoteDetailScreen(),
        AppRoutes.notesList: (context) => const NotesListScreen(),
        AppRoutes.tasks: (context) => const TasksScreen(),
        AppRoutes.phoneContactDetail: (context) => const PhoneContactDetailScreen(),
        AppRoutes.addNote: (context) => const AddNoteScreen(),
        AppRoutes.aiReview: (context) => const AiReviewScreen(),
        AppRoutes.reminderDetail: (context) => const ReminderDetailScreen(),
      },
    );
  }
}
