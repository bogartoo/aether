import 'package:aether/api/grok_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('chat parses completion content', () async {
    final client = GrokClient(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/chat/completions');
        return http.Response(
          '{"choices":[{"message":{"content":"hello from grok"}}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final text = await client.chat(
      accessToken: 'test',
      messages: [ChatMessage(role: 'user', content: 'hi')],
      model: 'grok-4',
    );
    expect(text, 'hello from grok');
  });

  test('generateImage returns b64 payload', () async {
    final client = GrokClient(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/images/generations');
        expect(request.body.contains('grok-imagine-image-2.0'), isTrue);
        return http.Response(
          '{"data":[{"b64_json":"abc123"}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final image = await client.generateImage(
      accessToken: 'test',
      prompt: 'a broken heart',
      model: 'grok-imagine-image-2.0',
      responseFormat: 'b64_json',
    );
    expect(image.b64Json, 'abc123');
  });
}
