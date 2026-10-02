import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../models/ai_result.dart';
import 'ai_provider.dart';
import 'ai_response_parser.dart';
import 'app_log.dart';
import 'api_key_service.dart';
import 'settings_service.dart';

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
  factory AiException.unknown(Object e) => AiException(message: 'AI analysis failed: $e', type: ExceptionType.unknown);

  @override
  String toString() => message;
}

enum ExceptionType { network, rateLimit, invalidKey, unknown }

/// Talks to any OpenAI-compatible chat-completions API (Groq, OpenRouter, NVIDIA…).
class AiService {
  static const _timeout = Duration(seconds: 60);

  final AiProvider provider;
  final String model;
  final String _apiKey;
  final http.Client? _client;

  /// [client] is for tests (e.g. `MockClient`); production uses a one-off client per call.
  AiService({required this.provider, required String apiKey, String? model, http.Client? client})
    : _apiKey = apiKey,
      _client = client,
      model = (model == null || model.trim().isEmpty) ? provider.defaultModel : model.trim();

  /// Builds a service from the provider, key and model saved in Settings.
  /// Returns null when no key is configured for the selected provider.
  static Future<AiService?> fromSettings() async {
    final settings = SettingsService();
    final provider = await settings.getAiProvider();
    final key = await ApiKeyService().getKey(provider);
    if (key == null || key.isEmpty) return null;
    return AiService(provider: provider, apiKey: key, model: await settings.getAiModel(provider));
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  /// gpt-oss models spend tokens "thinking" first; keep that short.
  bool get _isReasoningModel => model.contains('gpt-oss');

  Map<String, dynamic> _requestBody(
    List<Map<String, String>> messages, {
    required int maxTokens,
    double temperature = 0.3,
    Map<String, dynamic>? responseFormat,
  }) {
    return {
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
      if (_isReasoningModel && provider.id == AiProvider.groq.id) 'reasoning_effort': 'low',
      'response_format': ?responseFormat,
    };
  }

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

  Future<http.Response> _post(Map<String, dynamic> body) {
    final url = Uri.parse(provider.chatCompletionsUrl);
    final encoded = jsonEncode(body);
    final client = _client;
    final request = client != null
        ? client.post(url, headers: _headers, body: encoded)
        : http.post(url, headers: _headers, body: encoded);
    return request.timeout(_timeout);
  }

  /// Sends a tiny request to check the key and model. Returns 'valid' or an error description.
  Future<String> validateKey() async {
    try {
      final response = await _post(
        _requestBody(
          [
            {'role': 'user', 'content': 'Reply with the word OK.'},
          ],
          maxTokens: 256,
          temperature: 0,
        ),
      );

      switch (response.statusCode) {
        case 200:
          return 'valid';
        case 401:
        case 403:
          return 'api_error: Invalid API key (${response.statusCode})';
        case 404:
          return 'api_error: Model "$model" not found. ${_extractErrorMessage(response.body)}';
        case 429:
          return 'api_error: Rate limited. ${_extractErrorMessage(response.body)}';
        default:
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
      throw AiException.unknown(e);
    }
  }

  /// Strict schema for providers that support it. Every field is required, so
  /// "no reminder" is expressed as an empty title rather than null.
  static const Map<String, dynamic> _noteSchema = {
    'type': 'json_schema',
    'json_schema': {
      'name': 'note_analysis',
      'strict': true,
      'schema': {
        'type': 'object',
        'properties': {
          'summary': {'type': 'string'},
          'actionItems': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'reminder': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string'},
              'suggestedDate': {'type': 'string'},
              'suggestedTime': {'type': 'string'},
            },
            'required': ['title', 'suggestedDate', 'suggestedTime'],
            'additionalProperties': false,
          },
        },
        'required': ['summary', 'actionItems', 'reminder'],
        'additionalProperties': false,
      },
    },
  };

  static const _systemPrompt = '''
You are an assistant inside SmartBroker, a CRM app for brokers.
The user just wrote a NOTE about a call or meeting with one contact.
Extract structured information FROM THE NOTE ONLY.

Respond ONLY with a JSON object in this exact format:
{
  "summary": "1-3 sentence factual summary of the NOTE",
  "actionItems": ["Specific task 1", "Specific task 2"],
  "reminder": {
    "title": "Short reminder title",
    "suggestedDate": "YYYY-MM-DD",
    "suggestedTime": "HH:MM"
  }
}

RULES:
- Summarize and extract ONLY from the NOTE. The BACKGROUND section is older context: never summarize it, never copy facts or tasks from it into your answer.
- Never invent details that are not in the NOTE. If the note is very short, the summary is one sentence restating it.
- Each action item is one clear task taken from the NOTE. No tasks in the note → empty array.
- Do not repeat tasks listed under EXISTING PENDING TASKS.
- reminder = the most important follow-up in the NOTE. Resolve relative dates ("tomorrow", "Monday next week", "in 3 days") using the CALENDAR provided — pick the exact date from that list. "Next week <day>" / "<day> next week" means that weekday in the following calendar week.
- If the note gives no time, use 09:00. If nothing needs a follow-up, set all three reminder fields to empty strings.
- Return pure JSON. No markdown, no explanations.''';

  /// Today plus the next 14 days with weekday names, so the model doesn't
  /// have to do calendar arithmetic to resolve "Monday next week".
  static String _calendarContext(DateTime now) {
    final day = DateFormat('EEEE yyyy-MM-dd');
    final buf = StringBuffer('Today: ${day.format(now)} ${DateFormat('HH:mm').format(now)}\n');
    for (var i = 1; i <= 14; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      buf.writeln('${day.format(d)}${i == 1 ? ' (tomorrow)' : ''}');
    }
    return buf.toString().trimRight();
  }

  Future<AiResult> _callWithRetry({
    required String contactName,
    required String rawNote,
    required String previousNotes,
    required String pendingTodos,
    int maxRetries = 1,
  }) async {
    final userPrompt =
        '''
CONTACT: $contactName

CALENDAR:
${_calendarContext(DateTime.now())}

NOTE (the only text to summarize and extract from):
"""
$rawNote
"""

BACKGROUND — earlier note summaries for this contact (context only, do NOT summarize):
$previousNotes

EXISTING PENDING TASKS (do not repeat):
$pendingTodos''';

    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    var useSchema = provider.supportsJsonSchema;
    var attempts = 0;
    while (attempts <= maxRetries) {
      try {
        attempts++;
        final response = await _post(
          _requestBody(
            messages,
            maxTokens: 2048,
            responseFormat: useSchema ? _noteSchema : null,
          ),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) {
            throw Exception('API returned no choices');
          }
          final content = choices.first['message']['content'] as String?;
          if (content == null || content.trim().isEmpty) {
            throw Exception('API returned empty content');
          }
          // Full text only in debug builds: it summarises the user's client notes.
          AppLog.d(
            'AiService',
            kDebugMode
                ? '[${provider.id}/$model] response: $content'
                : '[${provider.id}/$model] response (${content.length} chars)',
          );
          return AiResponseParser.parse(content);
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw AiException.invalidKey();
        } else if (response.statusCode == 429) {
          throw AiException.rateLimited();
        } else if (response.statusCode == 400 && useSchema) {
          final body = response.body;
          AppLog.w(
            'AiService',
            'structured output rejected, retrying without it',
            body.length > 300 ? body.substring(0, 300) : body,
          );
          // The chosen model may not support structured output — retry without it.
          useSchema = false;
          attempts--;
          continue;
        } else {
          throw Exception('HTTP ${response.statusCode}: ${_extractErrorMessage(response.body)}');
        }
      } on TimeoutException {
        throw AiException.unknown(
          'Request timed out — the AI model is too slow. Try again later or pick a different model in Settings.',
        );
      } on AiException {
        rethrow;
      } catch (e) {
        if (attempts > maxRetries) {
          throw AiException.unknown(e);
        }
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    throw AiException.unknown('Max retries exceeded');
  }
}
