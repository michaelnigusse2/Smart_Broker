import 'package:flutter/material.dart';

/// Asks what to do with a reminder whose time has already passed.
/// Returns true to save it anyway (no notification will fire), false to go
/// back and pick another time.
Future<bool> confirmPastReminder(BuildContext context) async {
  final saveAnyway = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('This time has already passed'),
      content: const Text(
        "A reminder in the past won't send a notification. Change the time, or save it anyway?",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save anyway')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Change time')),
      ],
    ),
  );
  return saveAnyway ?? false;
}
