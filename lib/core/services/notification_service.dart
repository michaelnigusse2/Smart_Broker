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

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    // flutter_timezone 5.x returns TimezoneInfo — use .identifier for the IANA name
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    // 2. Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
    );

    // 5. Request Android 13+ runtime notification permission
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request exact alarm permission for Android 12+
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    if (response.payload != null && response.payload!.startsWith('/add-note')) {
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
          },
        );
      }
    }
  }

  /// Shows an immediate local notification after a phone call ends.
  Future<void> showPostCallPrompt(Contact contact, CallEntry call) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'post_call_prompts',
        'Post-Call Prompts',
        channelDescription: 'Prompts to add notes after phone calls',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final durationStr = '${call.duration.inMinutes}m ${call.duration.inSeconds % 60}s';

    await _plugin.show(
      id: call.id.hashCode.abs(),
      title: 'Call with ${contact.name}',
      body: 'Tap to add a note about this call ($durationStr)',
      notificationDetails: notificationDetails,
      payload: '/add-note?contactId=${contact.id}&duration=$durationStr',
    );
  }

  /// Schedules a local notification for an upcoming, incomplete reminder.
  Future<void> scheduleReminder(Reminder reminder) async {
    if (reminder.completed || reminder.dateTime.isBefore(DateTime.now())) {
      return;
    }

    // Derive a stable integer ID from the UUID string
    final int notificationId = reminder.id.hashCode.abs();

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',   // channel id
        'Reminders',   // channel name
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
        body: reminder.description.isNotEmpty
            ? reminder.description
            : 'You have an upcoming reminder.',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // If exact alarm permission was denied, silently skip
      // ignore: avoid_print
      print('NotificationService: failed to schedule alarm: $e');
    }
  }

  /// Cancels a previously scheduled notification by reminder ID.
  Future<void> cancelReminder(String reminderId) async {
    // v20+ cancel() uses named param `id`
    await _plugin.cancel(id: reminderId.hashCode.abs());
  }

  /// Cancels all pending notifications and reschedules from the DB.
  Future<void> rescheduleAll() async {
    await _plugin.cancelAll();

    final upcoming = await ReminderRepository().getUpcoming();
    for (final reminder in upcoming) {
      await scheduleReminder(reminder);
    }
  }
}
