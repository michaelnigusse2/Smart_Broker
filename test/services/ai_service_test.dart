import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_broker/core/services/ai_provider.dart';
import 'package:smart_broker/core/services/ai_service.dart';

/// A chat-completions response whose message content is [content].
http.Response _completion(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': content}
          }
        ]
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

const _validJson =
    '{"summary": "Wants a viewing.", "actionItems": ["Book viewing"], '
    '"reminder": {"title": "Viewing", "suggestedDate": "2026-10-05", "suggestedTime": "10:00"}}';

void main() {
  late List<http.Request> requests;
  late List<http.Response> replies;

  MockClient client() => MockClient((request) async {
        requests.add(request);
        return replies.removeAt(0);
      });

  Map<String, dynamic> body(int i) => jsonDecode(requests[i].body) as Map<String, dynamic>;

  Future<void> analyze(AiService service) => service.analyzeNote(
        contactName: 'Test Client One',
        rawNote: 'Viewing on Monday at 10',
        previousNotes: 'Looked at a flat in March',
        pendingTodos: '- Send floor plan',
      );

  setUp(() {
    requests = [];
    replies = [];
  });

  test('parses a JSON answer wrapped in a code fence', () async {
    replies.add(_completion('```json\n$_validJson\n```'));
    final service = AiService(provider: AiProvider.groq, apiKey: 'test-key', client: client());

    final result = await service.analyzeNote(
      contactName: 'Test Client One',
      rawNote: 'Viewing on Monday at 10',
      previousNotes: '',
      pendingTodos: '',
    );

    expect(result.summary, 'Wants a viewing.');
    expect(result.actionItems, ['Book viewing']);
    expect(result.reminderTitle, 'Viewing');
    expect(result.reminderDate, DateTime(2026, 10, 5, 10));
  });

  test('Groq request: bearer key, default model, strict schema, low reasoning effort', () async {
    replies.add(_completion(_validJson));

    await analyze(AiService(provider: AiProvider.groq, apiKey: 'test-key', model: '  ', client: client()));

    final request = requests.single;
    expect(request.url.toString(), AiProvider.groq.chatCompletionsUrl);
    expect(request.headers['Authorization'], 'Bearer test-key');
    final sent = body(0);
    expect(sent['model'], AiProvider.groq.defaultModel);
    expect(sent['reasoning_effort'], 'low');
    expect(sent['response_format']['type'], 'json_schema');
    final userMessage = (sent['messages'] as List).last['content'] as String;
    expect(userMessage, contains('Viewing on Monday at 10'));
    expect(userMessage.indexOf('NOTE'), lessThan(userMessage.indexOf('BACKGROUND')));
    expect(userMessage, contains('CALENDAR'));
  });

  test('OpenRouter request has no schema and no Groq-only fields', () async {
    replies.add(_completion(_validJson));

    await analyze(AiService(provider: AiProvider.openRouter, apiKey: 'k', client: client()));

    final sent = body(0);
    expect(sent['model'], AiProvider.openRouter.defaultModel);
    expect(sent.containsKey('reasoning_effort'), isFalse);
    expect(sent.containsKey('response_format'), isFalse);
  });

  test('HTTP 400 with a schema retries once without it', () async {
    replies
      ..add(http.Response('{"error": {"message": "response_format not supported"}}', 400))
      ..add(_completion(_validJson));

    await analyze(AiService(provider: AiProvider.groq, apiKey: 'k', model: 'some/model', client: client()));

    expect(requests, hasLength(2));
    expect(body(0).containsKey('response_format'), isTrue);
    expect(body(1).containsKey('response_format'), isFalse);
  });

  for (final (status, type) in [
    (401, ExceptionType.invalidKey),
    (403, ExceptionType.invalidKey),
    (429, ExceptionType.rateLimit),
  ]) {
    test('HTTP $status is reported as $type without retrying', () async {
      replies.add(http.Response('{"error": "nope"}', status));

      await expectLater(
        analyze(AiService(provider: AiProvider.groq, apiKey: 'k', client: client())),
        throwsA(isA<AiException>().having((e) => e.type, 'type', type)),
      );
      expect(requests, hasLength(1));
    });
  }

  test('validateKey maps responses to readable results', () async {
    replies
      ..add(_completion('OK'))
      ..add(http.Response('{"error": {"message": "model_not_found"}}', 404))
      ..add(http.Response('{}', 401));
    final service = AiService(provider: AiProvider.nvidia, apiKey: 'k', client: client());

    expect(await service.validateKey(), 'valid');
    expect(await service.validateKey(), allOf(startsWith('api_error: Model'), contains('model_not_found')));
    expect(await service.validateKey(), startsWith('api_error: Invalid API key'));
  });
}
