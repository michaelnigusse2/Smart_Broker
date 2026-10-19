import '../database/database_helper.dart';
import '../repositories/reminder_repository.dart';
import 'app_log.dart';
import 'call_overlay_state.dart';
import 'notification_service.dart';
import 'overlay_draft_service.dart';

/// Wipes everything SmartBroker stores on this phone (Settings → Reset local data).
///
/// Settings (AI provider, consent, call options) and the API key are kept.
class LocalDataService {
  final Future<void> Function(String reminderId) _cancelReminder;
  final Future<void> Function() _clearCallState;

  /// The hooks are injectable so tests don't need the plugins.
  LocalDataService({
    Future<void> Function(String reminderId)? cancelReminder,
    Future<void> Function()? clearCallState,
  }) : _cancelReminder = cancelReminder ?? NotificationService().cancelReminder,
       _clearCallState = clearCallState ?? _clearOverlayData;

  static Future<void> _clearOverlayData() async {
    await CallOverlayState.clearAll();
    await OverlayDraftService().clearAll();
  }

  Future<void> resetAll() async {
    // Cancel reminder alarms while the reminders can still be read.
    try {
      for (final reminder in await ReminderRepository().getAll()) {
        await _cancelReminder(reminder.id);
      }
    } catch (e) {
      AppLog.w('LocalData', 'could not cancel reminder notifications', e);
    }
    await DatabaseHelper.deleteLocalDatabase();
    await _clearCallState();
    await DatabaseHelper().database; // recreate an empty database right away
    AppLog.i('LocalData', 'local data reset');
  }
}
