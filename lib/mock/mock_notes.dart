import '../models/note.dart';

final mockNotes = [
  Note(
    id: 'n1',
    contactId: 'c1',
    rawText: 'Spoke with Sarah about the upcoming Q3 infrastructure upgrade. She mentioned they are leaning towards AWS but need a cost breakdown. Need to send that over by Friday. Also, ask her if she wants to grab coffee next Tuesday.',
    aiSummary: 'Discussed Q3 infrastructure upgrade. Client prefers AWS but requires a cost breakdown. Promised to deliver by Friday. Also suggested coffee next Tuesday.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Note(
    id: 'n2',
    contactId: 'c1',
    rawText: 'Quick check-in call. She said the board approved the budget for Q3. We are good to go on the initial planning phase.',
    aiSummary: 'Board approved Q3 budget. Ready for initial planning phase.',
    createdAt: DateTime.now().subtract(const Duration(days: 14)),
  ),
  Note(
    id: 'n3',
    contactId: 'c2',
    rawText: 'Michael wants to see a demo of our new analytics dashboard. I told him we could schedule something for next week. He also asked about integration with their existing CRM system.',
    aiSummary: 'Client requested demo of analytics dashboard for next week. Inquired about integration capabilities with their current CRM.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Note(
    id: 'n4',
    contactId: 'c3',
    rawText: 'Elena is frustrated with the current vendor. They missed another deadline. She is actively looking for alternatives. This is a great opportunity for us to pitch our enterprise tier.',
    aiSummary: 'Client dissatisfied with current vendor due to missed deadlines. Actively seeking alternatives. Excellent opportunity to pitch enterprise tier.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];
