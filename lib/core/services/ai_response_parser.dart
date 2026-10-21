import 'dart:convert';
import '../../models/ai_result.dart';

class AiResponseParser {
  static AiResult parse(String rawResponse) {
    try {
      // 1. Strip any markdown code fences
      String cleaned = rawResponse.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();

      // Ensure we only parse the JSON part if there is surrounding text
      final startIndex = cleaned.indexOf('{');
      final endIndex = cleaned.lastIndexOf('}');
      if (startIndex >= 0 && endIndex >= 0) {
        cleaned = cleaned.substring(startIndex, endIndex + 1);
      }

      // 2. Parse JSON
      final Map<String, dynamic> json = jsonDecode(cleaned);

      // 3. Extract fields with fallbacks
      final summary = json['summary']?.toString() ?? '';
      final actionItems = (json['actionItems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      // Older answers (and models that skip it) have no theirItems.
      final theirItems = (json['theirItems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final reminder = json['reminder'];

      // 4. Parse reminder date if present
      DateTime? reminderDate;
      String? reminderTitle;

      if (reminder != null && reminder is Map<String, dynamic>) {
        final title = reminder['title']?.toString().trim() ?? '';
        // An empty title means the model decided no follow-up is needed.
        reminderTitle = title.isEmpty ? null : title;
        final dateStr = reminder['suggestedDate']?.toString();
        final timeStr = reminder['suggestedTime']?.toString();

        if (dateStr != null && timeStr != null && dateStr.isNotEmpty && timeStr.isNotEmpty) {
          try {
            // Accept both HH:MM and HH:MM:SS.
            final hhmm = timeStr.length > 5 ? timeStr.substring(0, 5) : timeStr;
            reminderDate = DateTime.parse('${dateStr}T$hhmm:00');
          } catch (e) {
            // Ignore parse errors, reminderDate will be null
          }
        }
      }

      return AiResult(
        summary: summary,
        actionItems: actionItems,
        theirItems: theirItems,
        reminderTitle: reminderTitle,
        reminderDate: reminderDate,
      );
    } catch (e) {
      throw FormatException('Failed to parse AI response: $e\nRaw Response: $rawResponse');
    }
  }
}
