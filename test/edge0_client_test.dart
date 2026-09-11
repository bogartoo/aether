import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hrtbrkr/api/edge0_client.dart';

void main() {
  test('health parses Edge0 /healthz', () async {
    final client = Edge0Client(
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/healthz');
        return http.Response(
          jsonEncode({'status': 'ok', 'model': 'edge0-8b'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final health = await client.health();
    expect(health.ok, isTrue);
    expect(health.model, 'edge0-8b');
  });

  test('chat returns assistant content', () async {
    final client = Edge0Client(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/chat/completions');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['stream'], isFalse);
        return http.Response(
          jsonEncode({
            'id': 'chatcmpl-1',
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'hello from edge0'},
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final text = await client.chat(
      messages: [ChatMessage(role: 'user', content: 'hi')],
      model: 'edge0-8b',
    );
    expect(text, 'hello from edge0');
  });

  test('chatStream yields SSE deltas', () async {
    final client = Edge0Client(
      client: MockClient((request) async {
        expect(request.headers['Accept'], 'text/event-stream');
        const payload = 'data: {"choices":[{"delta":{"content":"He"}}]}\n\n'
            'data: {"choices":[{"delta":{"content":"llo"}}]}\n\n'
            'data: [DONE]\n\n';
        return http.Response(
          payload,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final parts = await client
        .chatStream(messages: [ChatMessage(role: 'user', content: 'hi')])
        .toList();
    expect(parts.join(), 'Hello');
  });
}
