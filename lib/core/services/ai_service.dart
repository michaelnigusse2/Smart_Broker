import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../models/ai_result.dart';
import 'ai_response_parser.dart';

class AiException implements Exception {
  final String message;
  final ExceptionType type;

  AiException({required this.message, required this.type});

  factory AiException.networkError() =>
      AiException(message: 'No internet connection or network error.', type: ExceptionType.network);
  factory AiException.rateLimited() =>
      AiException(message: 'Too many requests. Please wait a moment.', type: ExceptionType.rateLimit);
  factory AiException.invalidKey() =>
      AiException(message: 'Invalid API key. Please update in Settings.', type: ExceptionType.invalidKey);
  factory AiException.unknown(Object e) =>
      AiException(message: 'AI analysis failed: $e', type: ExceptionType.unknown);

  @override
  String toString() => message;
}

enum ExceptionType { network, rateLimit, invalidKey, unknown }

class AiService {
  static const String _baseUrl = 'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String _model = 'meta/llama-3.1-8b-instruct';

  final String _apiKey;

  AiService({required String apiKey}) : _apiKey = apiKey;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

  String _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString() ?? body;
      }
      return error?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  Future<String> validateKey() async {
    try {
      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': 'Respond with exactly the word OK and nothing else.'}
        ],
        'temperature': 0.2,
        'top_p': 0.7,
        'max_tokens': 16,
        'stream': false,
      });

      final response = await http
          .post(Uri.parse(_baseUrl), headers: _headers, body: body)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        final content = (choices != null && choices.isNotEmpty)
            ? (choices.first['message']['content'] as String?)?.trim()
            : null;
        if (content != null && content.toUpperCase() == 'OK') {
          return 'valid';
        }
        return 'unexpected_response: $content';
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return 'api_error: Invalid API key (${response.statusCode})';
      } else if (response.statusCode == 429) {
        return 'api_error: Rate limited. ${_extractErrorMessage(response.body)}';
      } else {
        return 'api_error: ${response.statusCode} - ${_extractErrorMessage(response.body)}';
      }
    } on TimeoutException {
      return 'timeout: request took too long';
    } catch (e) {
      return 'unknown_error: $e';
    }
  }

  Future<AiResult> analyzeNote({
    required String contactName,
    required String rawNote,
    required String previousNotes,
    required String pendingTodos,
  }) async {
    try {
      return await _callWithRetry(
        contactName: contactName,
        rawNote: rawNote,
        previousNotes: previousNotes,
        pendingTodos: pendingTodos,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException.unknown(e);
    }
  }

  Future<AiResult> _callWithRetry({
    required String contactName,
    required String rawNote,
    required String previousNotes,
    required String pendingTodos,
    int maxRetries = 1,
  }) async {
    int attempts = 0;
    while (attempts <= maxRetries) {
      try {
        attempts++;
        final currentDateTime = DateTime.now().toIso8601String();

        final prompt = '''
You are an AI assistant for a CRM app called SmartBroker.
Analyze the following meeting note and extract structured information.

CONTACT: $contactName
CURRENT DATE: $currentDateTime
NOTE: $rawNote

PREVIOUS CONTEXT:
$previousNotes

EXISTING PENDING TASKS:
$pendingTodos

Respond ONLY with a JSON object in this exact format:
{
  "summary": "A concise 2-3 sentence summary of the key discussion points",
  "actionItems": [
    "Specific actionable task 1",
    "Specific actionable task 2"
  ],
  "reminder": {
    "title": "Brief reminder title",
    "suggestedDate": "YYYY-MM-DD",
    "suggestedTime": "HH:MM (24h format)"
  }
}

RULES:
- The summary should be factual and concise. Do not add information not present in the note.
- Each action item should be a single clear task. Do not combine multiple tasks into one.
- If there are no clear action items, return an empty array.
- The reminder should be about the most important follow-up. If nothing needs follow-up, set reminder to null.
- The suggestedDate should be a real calendar date.
- Do not include tasks that already exist in the pending tasks list.
- Do not use markdown formatting. Return pure JSON only.
''';

        final body = jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'top_p': 0.7,
          'max_tokens': 1024,
          'stream': false,
        });

        final response = await http
            .post(Uri.parse(_baseUrl), headers: _headers, body: body)
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) {
            throw Exception('API returned no choices');
          }
          final content = choices.first['message']['content'] as String?;
          if (content == null) {
            throw Exception('API returned null content');
          }
          return AiResponseParser.parse(content);
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw AiException.invalidKey();
        } else if (response.statusCode == 429) {
          throw AiException.rateLimited();
        } else {
          throw Exception('HTTP ${response.statusCode}: ${_extractErrorMessage(response.body)}');
        }
      } on TimeoutException {
        throw AiException.unknown('Request timed out — the AI model is too slow. Try again later or switch to a smaller model.');
      } on AiException {
        rethrow;
      } catch (e) {
        if (e is AiException) rethrow;
        if (attempts > maxRetries) {
          throw AiException.unknown(e);
        }
        await Future.delayed(Duration(seconds: 1 * attempts));
      }
    }
    throw AiException.unknown('Max retries exceeded');
  }
}