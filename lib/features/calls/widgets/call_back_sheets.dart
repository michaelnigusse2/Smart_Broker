import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/phone_dialer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/call_backs.dart';
import '../../../core/utils/day_labels.dart';
import '../../../models/contact.dart';
import '../../../models/reminder.dart';

String _first(Contact c) => c.name.trim().split(RegExp(r'\s+')).first;
String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Missed 2 calls · 10:42", "Yesterday · you tried at 16:05".
String callBackLine(CallBack cb, DateTime now) {
  final days = DayLabels.daysBetween(cb.lastMissedAt, now);
  final when = days == 0
      ? _clock(cb.lastMissedAt)
      : days == 1
      ? 'yesterday'
      : DateFormat('EEE').format(cb.lastMissedAt);
  if (cb.triedAt != null) {
    final day = days == 0 ? 'Missed' : '${when[0].toUpperCase()}${when.substring(1)}';
    return '$day · you tried at ${_clock(cb.triedAt!)}';
  }
  return cb.missed > 1 ? 'Missed ${cb.missed} calls · $when' : 'Missed · $when';
}

/// When a call back reminder is due: "18:00" today, else "Sat 09:00".
String reminderWhen(DateTime at, DateTime now) =>
    DayLabels.daysBetween(now, at) == 0 ? _clock(at) : '${DateFormat('EEE').format(at)} ${_clock(at)}';

/// Calls them now.
Future<void> callBackNow(Contact contact) => PhoneDialer.dial(contact.phoneNumber);

/// "Not needed": hides their missed calls until the next one.
Future<void> callBackNotNeeded(Contact contact) async {
  await ContactRepository().clearCallBack(contact.id, DateTime.now());
  final done = await ReminderRepository().completeCallBacks(contact.id);
  try {
    for (final r in done) {
      await NotificationService().cancelReminder(r.id);
    }
    await NotificationService().cancelMissedCallPrompt(contact.id);
  } catch (e) {
    AppLog.w('CallBack', 'could not clear its notifications', e);
  }
}

/// The times "Remind me" offers.
@visibleForTesting
List<(String, DateTime)> remindOptions(DateTime now) {
  final inAnHour = now.add(const Duration(hours: 1));
  final rounded = DateTime(inAnHour.year, inAnHour.month, inAnHour.day, inAnHour.hour, (inAnHour.minute + 4) ~/ 5 * 5);
  final evening = DateTime(now.year, now.month, now.day, 18);
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
  return [
    ('In an hour', rounded),
    if (now.isBefore(evening.subtract(const Duration(minutes: 30)))) ('This evening', evening),
    ('Tomorrow morning', tomorrow),
  ];
}

/// "Call Selam back": pick a time, and it's on Today, the calendar and an
/// alert. Returns the time chosen, or null.
Future<DateTime?> showRemindCallBackSheet(BuildContext context, Contact contact) async {
  final messenger = ScaffoldMessenger.of(context);
  final at = await showModalBottomSheet<DateTime>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.sb.canvas,
    builder: (_) => _RemindSheet(contact: contact),
  );
  if (at == null) return null;
  // One call-back reminder per person: a new time replaces the old one.
  final repo = ReminderRepository();
  for (final old in await repo.openCallBacks(contact.id)) {
    await repo.delete(old.id);
    await NotificationService().cancelReminder(old.id);
  }
  final id = await repo.insert(
    Reminder(
      id: '',
      contactId: contact.id,
      title: 'Call ${_first(contact)} back',
      description: 'They called and you missed it',
      dateTime: at,
      createdAt: DateTime.now(),
      kind: Reminder.callBack,
    ),
  );
  final saved = await repo.getById(id);
  if (saved != null) await NotificationService().scheduleReminder(saved);
  await NotificationService().cancelMissedCallPrompt(contact.id);
  final now = DateTime.now();
  final when = DayLabels.daysBetween(now, at) == 0
      ? 'at ${_clock(at)}'
      : '${DateFormat('EEE').format(at)} ${_clock(at)}';
  messenger.showSnackBar(SnackBar(content: Text("We'll remind you $when")));
  return at;
}

class _RemindSheet extends StatefulWidget {
  const _RemindSheet({required this.contact});

  final Contact contact;

  @override
  State<_RemindSheet> createState() => _RemindSheetState();
}

class _RemindSheetState extends State<_RemindSheet> {
  late final List<(String, DateTime)> _options = remindOptions(DateTime.now());
  int _picked = 0;
  DateTime? _custom;

  DateTime? get _chosen => _picked < _options.length ? _options[_picked].$2 : _custom;

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _custom = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      _picked = _options.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    String label(DateTime t) => reminderWhen(t, now);
    Widget option(int index, String title, String time, VoidCallback onTap) {
      final on = index == _picked;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: index == 0 ? null : Border(top: BorderSide(color: sb.fill)),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: on ? sb.primary : sb.track, width: on ? 7 : 2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sb.text2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final chosen = _chosen;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SbFace(name: widget.contact.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call ${_first(widget.contact)} back', style: text.headlineSmall),
                    Text(
                      "We'll remind you, and it shows on Today",
                      style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SbCard(
            child: Column(
              children: [
                for (final (i, (title, at)) in _options.indexed)
                  option(i, title, label(at), () => setState(() => _picked = i)),
                option(_options.length, 'Pick a time', _custom == null ? '' : label(_custom!), _pickTime),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SbPrimaryButton(
            label: chosen == null
                ? 'Remind me'
                : 'Remind me ${DayLabels.daysBetween(now, chosen) == 0 ? 'at ' : ''}${label(chosen)}',
            icon: LucideIcons.bell,
            onPressed: chosen == null ? null : () => Navigator.pop(context, chosen),
          ),
        ],
      ),
    );
  }
}

/// Long-press on a call back: Call back / Remind me / Not needed. Returns
/// true when something changed.
Future<bool> showCallBackActions(BuildContext context, CallBack cb) async {
  final sb = context.sb;
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: sb.canvas,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                SbFace(name: cb.contact.name, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cb.contact.name, style: Theme.of(ctx).textTheme.titleMedium),
                      Text(callBackLine(cb, DateTime.now()), style: TextStyle(fontSize: 13, color: sb.text2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SbCard(
            child: Column(
              children: [
                SbListRow(
                  first: true,
                  leading: SbIconTile(icon: LucideIcons.phone, tint: sb.tintGreen),
                  title: 'Call back',
                  onTap: () => Navigator.pop(ctx, 'call'),
                ),
                SbListRow(
                  leading: SbIconTile(icon: LucideIcons.bell, tint: sb.tintCool),
                  title: 'Remind me',
                  subtitle: cb.reminder == null ? null : 'Now ${reminderWhen(cb.reminder!.dateTime, DateTime.now())}',
                  onTap: () => Navigator.pop(ctx, 'remind'),
                ),
                SbListRow(
                  leading: SbIconTile(icon: LucideIcons.x, tint: sb.faces.last),
                  title: 'Not needed',
                  subtitle: 'Until they call again',
                  onTap: () => Navigator.pop(ctx, 'clear'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  switch (action) {
    case 'call':
      await callBackNow(cb.contact);
      return false;
    case 'remind':
      return await showRemindCallBackSheet(context, cb.contact) != null;
    case 'clear':
      await callBackNotNeeded(cb.contact);
      return true;
  }
  return false;
}
