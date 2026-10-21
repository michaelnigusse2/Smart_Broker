import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io' show Platform;
import '../../models/reminder.dart';
import '../repositories/reminder_repository.dart';
import '../../models/contact.dart';
import '../../models/call_entry.dart';
import '../constants/app_routes.dart';
import 'call_overlay_state.dart';
import 'app_log.dart';
import '../utils/reminder_time.dart';
import 'wrap_up_store.dart';

/// Handles the after-call notification's buttons while the app isn't open.
/// Runs in its own isolate, so it only touches storage.
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.handleAction(response);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// True when the device's timezone wasn't recognised and UTC is used instead.
  /// Reminders still fire at the right moment (they're scheduled as absolute
  /// instants); only wall-clock-based schedules would be affected.
  bool timezoneFallback = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    // flutter_timezone 5.x returns TimezoneInfo — use .identifier for the IANA name
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      // Some ROMs report identifiers missing from the bundled tz database.
      AppLog.w('Notifications', 'unknown timezone, using UTC', e);
      tz.setLocalLocation(tz.UTC);
      timezoneFallback = true;
    }

    // 2. Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS settings — explicitly request all three permissions
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Initialize the plugin (v20+ uses named param `settings`)
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onNotificationActionInBackground,
    );

    // 5. Request Android 13+ runtime notification permission
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Exact alarm permission (Android 12+). Only ask when it isn't granted —
      // asking opens a system settings page every time.
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null && !(await android.canScheduleExactNotifications() ?? false)) {
        await android.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  /// The after-call notification's buttons. "Settled" and "Add note" take
  /// the call off the wrap-up list; "Not now" leaves it there for Today.
  /// Returns true when the response needs nothing more (no screen to open).
  static Future<bool> handleAction(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('/add-note')) return false;
    final callId = Uri.parse(payload).queryParameters['callId'];
    switch (response.actionId) {
      case 'settled':
        if (callId != null) await WrapUpStore.remove(callId);
        return true;
      case 'later':
        return true;
      default:
        if (callId != null) await WrapUpStore.remove(callId);
        return false;
    }
  }

  Future<void> _onResponse(NotificationResponse response) async {
    // The moments marked during the call, read before the call leaves the
    // wrap-up list, so the note screen can show them.
    final callId = response.payload == null ? null : Uri.tryParse(response.payload!)?.queryParameters['callId'];
    final wrapUp = callId == null ? null : await WrapUpStore.find(callId);
    if (await handleAction(response)) return;
    if (response.payload != null && response.payload!.startsWith('/add-note')) {
      // A note already written in the call overlay goes straight to AI Review.
      final pending = await CallOverlayState.takePendingReview();
      if (pending != null) {
        final noteId = await CallOverlayState.savePendingNote(pending);
        AppRoutes.globalNavigatorKey.currentState?.pushNamed(
          AppRoutes.aiReview,
          arguments: {...pending, 'noteId': ?noteId},
        );
        return;
      }
      if (CallOverlayState.tookRecently) return; // AI Review was just opened on resume.

      final uri = Uri.parse(response.payload!);
      final contactId = uri.queryParameters['contactId'];
      final duration = uri.queryParameters['duration'];
      if (contactId != null) {
        AppRoutes.globalNavigatorKey.currentState?.pushNamed(
          AppRoutes.addNote,
          arguments: {
            'contactId': contactId,
            'isPostCall': true,
            'duration': duration,
            'marks': wrapUp?.marks ?? const [],
          },
        );
      }
    }
  }

  /// The one quiet notification after a call (the "Espresso · final"
  /// after-call board): "Call with Selam · 6:42", what you owe and how many
  /// moments you marked, and Settled / Add note / Not now. Silent: it shows
  /// at the top without a sound or buzz.
  Future<void> showPostCallPrompt(Contact contact, CallEntry call, {String owe = '', int marks = 0}) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'after_call',
        'After calls',
        channelDescription: 'One silent note after each call, to wrap it up',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.reminder,
        actions: [
          AndroidNotificationAction('settled', 'Settled', cancelNotification: true),
          AndroidNotificationAction('note', 'Add note', showsUserInterface: true, cancelNotification: true),
          AndroidNotificationAction('later', 'Not now', cancelNotification: true),
        ],
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
    );

    final seconds = call.duration.inSeconds;
    final length = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final first = contact.name.trim().split(RegExp(r'\s+')).first;
    final body = [
      if (owe.isNotEmpty) 'You owe: $owe',
      if (marks > 0) '$marks ${marks == 1 ? 'mark' : 'marks'}',
    ].join(' · ');

    await _plugin.show(
      id: stableNotificationId('call:${call.id}'),
      title: 'Call with $first · $length',
      body: body.isEmpty ? 'Add a note, or mark it settled' : body,
      notificationDetails: notificationDetails,
      payload: Uri(
        path: '/add-note',
        queryParameters: {'contactId': contact.id, 'duration': length, 'callId': call.id},
      ).toString(),
    );
  }

  /// Schedules a local notification for an upcoming, incomplete reminder.
  /// Returns false when nothing was scheduled (completed, in the past, or the
  /// OS refused).
  Future<bool> scheduleReminder(Reminder reminder) async {
    if (reminder.completed || !isSchedulable(reminder.dateTime)) {
      return false;
    }

    final int notificationId = stableNotificationId(reminder.id);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders', // channel id
        'Reminders', // channel name
        channelDescription: 'Notifications for upcoming reminders',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final scheduledDate = tz.TZDateTime.from(reminder.dateTime, tz.local);

    try {
      // v20+ zonedSchedule uses all named parameters
      await _plugin.zonedSchedule(
        id: notificationId,
        title: reminder.title,
        body: reminder.description.isNotEmpty ? reminder.description : 'You have an upcoming reminder.',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: await _scheduleMode(),
      );
      return true;
    } catch (e) {
      AppLog.w('Notifications', 'failed to schedule reminder ${reminder.id}', e);
      return false;
    }
  }

  /// Exact timing when allowed; otherwise inexact (may fire a few minutes late)
  /// rather than failing silently.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Cancels a previously scheduled notification by reminder ID.
  Future<void> cancelReminder(String reminderId) async {
    // v20+ cancel() uses named param `id`. Also cancel the id older builds
    // used, so alarms scheduled before the id change can't linger.
    await _plugin.cancel(id: stableNotificationId(reminderId));
    await _plugin.cancel(id: legacyNotificationId(reminderId));
  }

  /// Re-creates reminder alarms from the database.
  ///
  /// Only reminder notifications are touched — a post-call prompt that is
  /// still in the notification shade must survive the app being opened.
  Future<void> rescheduleAll() async {
    final reminders = await ReminderRepository().getAll();
    for (final reminder in reminders) {
      await cancelReminder(reminder.id);
      await scheduleReminder(reminder);
    }
  }
}
