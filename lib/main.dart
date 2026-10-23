import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'core/constants/app_routes.dart';
import 'core/database/seed_data.dart';
import 'core/repositories/contact_repository.dart';
import 'core/services/app_log.dart';
import 'core/services/call_detection_service.dart';
import 'core/services/call_matching_service.dart';
import 'core/services/call_overlay_state.dart';
import 'core/services/notification_service.dart';
import 'core/services/profile_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance.dart';
import 'core/transcription/licences.dart';
import 'core/widgets/sheet_route.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/calendar/screens/reminder_detail_screen.dart';
import 'features/calls/screens/call_overlay_screen.dart';
import 'features/calls/widgets/call_back_sheets.dart';
import 'features/contacts/screens/contact_detail_screen.dart';
import 'features/contacts/screens/contact_form_screen.dart';
import 'features/contacts/screens/new_numbers_screen.dart';
import 'features/contacts/screens/phone_contact_detail_screen.dart';
import 'features/contacts/widgets/who_was_this_sheet.dart';
import 'features/home/screens/main_shell.dart';
import 'features/home/screens/startup_error_screen.dart';
import 'features/notes/screens/add_note_screen.dart';
import 'features/notes/screens/ai_review_screen.dart';
import 'features/notes/screens/note_detail_screen.dart';
import 'features/notes/screens/notes_list_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/settings/screens/ai_helper_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/todos/screens/tasks_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Draw behind the status and navigation bars on every Android version.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemBars(PlatformDispatcher.instance.platformBrightness));
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Debug builds log the full report (it names the widget and source line,
      // e.g. which Row overflowed); release keeps it to one line.
      AppLog.e('Flutter', kDebugMode ? details.toString() : details.exceptionAsString(), null, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLog.e('Platform', 'uncaught error', error, stack);
      return true;
    };
    await _startApp();
  }, (error, stack) => AppLog.e('Zone', 'uncaught error', error, stack));
}

/// Runs startup and shows the app, or an error screen if the database can't
/// be opened. Called again by the error screen's "Try again".
Future<void> _startApp() async {
  final failure = await _initialise();
  if (failure != null) {
    runApp(StartupErrorApp(error: failure, onRetry: _startApp));
    return;
  }
  var onboarded = true;
  await AppearanceController.instance.load();
  try {
    await ProfileService().load();
    onboarded = await ProfileService().isOnboarded();
  } catch (e, st) {
    AppLog.e('Startup', 'could not read the profile', e, st);
  }
  runApp(SmartBrokerApp(showOnboarding: !onboarded));
}

/// Returns the error if a fatal step failed; non-fatal steps are logged and
/// skipped so a notification or call-detection problem never blocks the app.
Future<Object?> _initialise() async {
  try {
    await SeedData.seedIfNeeded(); // Opens the database.
  } catch (e, st) {
    AppLog.e('Startup', 'database unavailable', e, st);
    return e;
  }
  await _nonFatal('notifications', () => NotificationService().init());
  await _nonFatal('reminder rescheduling', () => NotificationService().rescheduleAll());
  registerDictationLicences();
  registerFontLicences();
  _listenToOverlayOnce();
  await _restoreCallDetection();
  return null;
}

Future<void> _nonFatal(String step, Future<void> Function() action) async {
  try {
    await action();
  } catch (e, st) {
    AppLog.e('Startup', '$step failed, continuing', e, st);
  }
}

bool _overlayListenerAttached = false;

/// Messages from the call overlay (best effort — see CallOverlayState).
/// The plugin's stream can only be listened to once per isolate.
void _listenToOverlayOnce() {
  if (_overlayListenerAttached) return;
  _overlayListenerAttached = true;
  try {
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && event['action'] == 'openAiReview') {
        openPendingAiReview();
      }
    });
  } catch (e) {
    AppLog.w('Startup', 'overlay listener unavailable', e);
  }
}

/// Entry point for the call overlay window. flutter_overlay_window looks this
/// function up by name in the app's main library, so it must live in this file.
@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The call card follows the theme picked in Settings.
  final appearance = await AppearanceController.read();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(appearance.theme),
      darkTheme: AppTheme.dark(appearance.theme),
      themeMode: appearance.mode,
      home: const CallOverlayScreen(),
    ),
  );
}

/// Restarts call detection on launch if the user had turned it on.
Future<void> _restoreCallDetection() async {
  if (!Platform.isAndroid) return;
  try {
    // A leftover overlay state from a previous session would confuse the overlay.
    await CallOverlayState.clear();
    if (!await SettingsService().getCallDetectionEnabled()) return;
    final detection = CallDetectionService();
    if (!await detection.isPermissionGranted()) return;
    if (await detection.start()) {
      CallMatchingService().startListening();
    }
  } catch (e) {
    AppLog.w('Startup', 'could not restore call detection', e);
  }
}

/// Opens AI Review for a note saved from the call overlay, if there is one.
Future<void> openPendingAiReview() async {
  final pending = await CallOverlayState.takePendingReview();
  if (pending == null) return;
  // Save the note first: the pending entry is gone now, so this is its only copy.
  // If that fails, AI Review gets the text and tries again.
  final noteId = await CallOverlayState.savePendingNote(pending);
  AppRoutes.globalNavigatorKey.currentState?.pushNamed(
    AppRoutes.aiReview,
    arguments: {...pending, 'noteId': ?noteId},
  );
}

class SmartBrokerApp extends StatefulWidget {
  const SmartBrokerApp({super.key, this.showOnboarding = false});

  /// First launch: start with onboarding instead of Today.
  final bool showOnboarding;

  @override
  State<SmartBrokerApp> createState() => _SmartBrokerAppState();
}

class _SmartBrokerAppState extends State<SmartBrokerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onCallBack = _onCallBackNotification;
    NotificationService.onNewNumber = _onNewNumberNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openPendingAiReview();
      NotificationService().handleLaunchNotification();
    });
  }

  /// Waits for the navigator (the app may still be starting) and a context
  /// under it, for sheets opened from notifications.
  static Future<BuildContext?> _navigatorContext() async {
    for (var i = 0; i < 40; i++) {
      final context = AppRoutes.globalNavigatorKey.currentContext;
      if (context != null && context.mounted) return context;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  /// Missed-call notification: Call back dials, Remind me picks a time, a
  /// tap opens the person.
  static Future<void> _onCallBackNotification(String contactId, String action) async {
    try {
      final contact = await ContactRepository().getById(contactId);
      if (contact == null) return;
      switch (action) {
        case 'callback':
          await NotificationService().cancelMissedCallPrompt(contactId);
          await callBackNow(contact);
        case 'remind':
          final context = await _navigatorContext();
          if (context == null || !context.mounted) return;
          await showRemindCallBackSheet(context, contact);
        default:
          await _navigatorContext(); // let the app finish starting
          AppRoutes.globalNavigatorKey.currentState?.pushNamed(AppRoutes.contactDetail, arguments: contactId);
      }
    } catch (e, st) {
      AppLog.e('Notifications', 'could not act on a missed call', e, st);
    }
  }

  /// New-number notification: Save (or a tap) asks "Who was this?".
  static Future<void> _onNewNumberNotification(String phoneKey) async {
    final context = await _navigatorContext();
    if (context == null || !context.mounted) return;
    await showWhoWasThisSheet(context, phoneKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) openPendingAiReview();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Appearance>(
      valueListenable: AppearanceController.instance,
      builder: (context, appearance, _) => _app(appearance),
    );
  }

  Widget _app(Appearance appearance) {
    return MaterialApp(
      title: 'SmartBroker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(appearance.theme),
      darkTheme: AppTheme.dark(appearance.theme),
      themeMode: appearance.mode,
      // Keeps the status and navigation bars see-through on every frame, so
      // nothing (a plugin, an older Android default) can turn them black.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemBars(Theme.of(context).brightness),
        child: child!,
      ),
      navigatorKey: AppRoutes.globalNavigatorKey,
      initialRoute: widget.showOnboarding ? AppRoutes.onboarding : AppRoutes.shell,
      routes: {
        AppRoutes.shell: (context) => const MainShell(),
        AppRoutes.contactDetail: (context) => const ContactDetailScreen(),
        AppRoutes.contactForm: (context) => const ContactFormScreen(),
        AppRoutes.noteDetail: (context) => const NoteDetailScreen(),
        AppRoutes.notesList: (context) => const NotesListScreen(),
        AppRoutes.tasks: (context) => const TasksScreen(),
        AppRoutes.phoneContactDetail: (context) => const PhoneContactDetailScreen(),
        AppRoutes.aiReview: (context) => const AiReviewScreen(),
        AppRoutes.reminderDetail: (context) => const ReminderDetailScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
        AppRoutes.calendar: (context) => const CalendarScreen(),
        AppRoutes.newNumbers: (context) => const NewNumbersScreen(),
        AppRoutes.ignoredNumbers: (context) => const IgnoredNumbersScreen(),
        AppRoutes.aiHelper: (context) => const AiHelperScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
      },
      // The quick note comes up as a sheet over the screen it's opened from.
      onGenerateRoute: (settings) => settings.name == AppRoutes.addNote
          ? SheetRoute<void>(settings: settings, builder: (_) => const AddNoteScreen())
          : null,
    );
  }
}
