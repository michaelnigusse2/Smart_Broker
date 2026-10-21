import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/services/ai_response_parser.dart';

void main() {
  group('AiResponseParser.parse', () {
    test('parses a complete response', () {
      const raw = '''
{
  "summary": "Discussed the Bole apartment listing.",
  "actionItems": ["Send floor plan", "Confirm viewing time"],
  "reminder": {
    "title": "Call back about viewing",
    "suggestedDate": "2026-10-02",
    "suggestedTime": "14:30"
  }
}''';

      final result = AiResponseParser.parse(raw);

      expect(result.summary, 'Discussed the Bole apartment listing.');
      expect(result.actionItems, ['Send floor plan', 'Confirm viewing time']);
      expect(result.reminderTitle, 'Call back about viewing');
      expect(result.reminderDate, DateTime(2026, 10, 2, 14, 30));
    });

    test('reads what the contact promised, and copes when it is missing', () {
      final result = AiResponseParser.parse(
        '{"summary": "S", "actionItems": ["Send numbers"], "theirItems": ["Signed offer"], "reminder": null}',
      );
      expect(result.actionItems, ['Send numbers']);
      expect(result.theirItems, ['Signed offer']);
      expect(AiResponseParser.parse('{"summary": "S", "actionItems": [], "reminder": null}').theirItems, isEmpty);
    });

    test('strips markdown code fences and surrounding text', () {
      const raw = 'Here you go:\n```json\n{"summary": "Short", "actionItems": [], "reminder": null}\n```';

      final result = AiResponseParser.parse(raw);

      expect(result.summary, 'Short');
      expect(result.actionItems, isEmpty);
      expect(result.reminderTitle, isNull);
      expect(result.reminderDate, isNull);
    });

    test('keeps reminder title when date is malformed', () {
      const raw =
          '{"summary": "S", "actionItems": [], '
          '"reminder": {"title": "Follow up", "suggestedDate": "next week", "suggestedTime": "soon"}}';

      final result = AiResponseParser.parse(raw);

      expect(result.reminderTitle, 'Follow up');
      expect(result.reminderDate, isNull);
    });

    test('treats an empty reminder title as no reminder', () {
      const raw =
          '{"summary": "S", "actionItems": ["A"], '
          '"reminder": {"title": "", "suggestedDate": "", "suggestedTime": ""}}';

      final result = AiResponseParser.parse(raw);

      expect(result.reminderTitle, isNull);
      expect(result.reminderDate, isNull);
    });

    test('accepts HH:MM:SS times', () {
      const raw =
          '{"summary": "S", "actionItems": [], '
          '"reminder": {"title": "Call", "suggestedDate": "2026-10-02", "suggestedTime": "09:05:00"}}';

      expect(AiResponseParser.parse(raw).reminderDate, DateTime(2026, 10, 2, 9, 5));
    });

    test('throws FormatException on non-JSON output', () {
      expect(
        () => AiResponseParser.parse('Sorry, I cannot help with that.'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
