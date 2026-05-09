import '../models/reminder.dart';

final mockReminders = [
  Reminder(
    id: 'r1',
    contactId: 'c1',
    title: 'Follow up on AWS cost breakdown',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
  ),
  Reminder(
    id: 'r2',
    contactId: 'c2',
    title: 'Product Demo - Analytics Dashboard',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 5)),
  ),
  Reminder(
    id: 'r3',
    contactId: 'c3',
    title: 'Pitch Enterprise Tier to Elena',
    dateTime: DateTime.now().add(const Duration(days: 5, hours: 1)),
  ),
  Reminder(
    id: 'r4',
    contactId: 'c8',
    title: 'Quarterly Review Meeting',
    dateTime: DateTime.now().add(const Duration(days: 10, hours: 4)),
  ),
  Reminder(
    id: 'r5',
    contactId: 'c4',
    title: 'Check in on Q2 Renewal',
    dateTime: DateTime.now().subtract(const Duration(hours: 5)), // Overdue
  ),
];
