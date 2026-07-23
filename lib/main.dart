import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'features/home/screens/main_shell.dart';
import 'features/contacts/screens/contact_detail_screen.dart';
import 'features/notes/screens/add_note_screen.dart';
import 'features/notes/screens/ai_review_screen.dart';

import 'core/database/seed_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SeedData.seedIfNeeded();
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
      initialRoute: AppRoutes.shell,
      routes: {
        AppRoutes.shell: (context) => const MainShell(),
        AppRoutes.contactDetail: (context) => const ContactDetailScreen(),
        AppRoutes.addNote: (context) => const AddNoteScreen(),
        AppRoutes.aiReview: (context) => const AiReviewScreen(),
      },
    );
  }
}
