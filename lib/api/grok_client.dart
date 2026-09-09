import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const kGrokApiBase = 'https://api.x.ai/v1';
const kDefaultGrokModel = 'grok-4';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.streaming = false,
  });

  final String role; // user | assistant | system
  String content;
  bool streaming;

  Map<String, String> toApi() => {'role': role, 'content': content};
}

class GrokClientException implements Exception {
  GrokClientException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class GrokClient {
  GrokClient({http.Client? client, this.baseUrl = kGrokApiBase})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// Non-streaming chat completion.
  Future<String> chat({
    required String accessToken,
    required List<ChatMessage> messages,
    String model = kDefaultGrokModel,
    String? systemPrompt,
  }) async {
    final payloadMessages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toApi()),
    ];

    final response = await _client.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'aether/1.0',
      },
      body: jsonEncode({
        'model': model,
        'messages': payloadMessages,
        'stream': false,
      }),
    );

    if (response.statusCode == 401) {
      throw GrokClientException('Unauthorized — sign in again', statusCode: 401);
    }
    if (response.statusCode == 403) {
      throw GrokClientException(
        'Access denied (403). Your SuperGrok / X Premium+ entitlement may not '
        'cover this API surface. Try again later or use an API key from console.x.ai.',
        statusCode: 403,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GrokClientException(
        'Grok request failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw GrokClientException('Empty response from Grok');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw GrokClientException('Malformed Grok response');
    }
    return content;
  }

  /// Streaming chat; yields text deltas.
  Stream<String> chatStream({
    required String accessToken,
    required List<ChatMessage> messages,
    String model = kDefaultGrokModel,
    String? systemPrompt,
  }) async* {
    final payloadMessages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toApi()),
    ];

    final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'));
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'User-Agent': 'aether/1.0',
    });
    request.body = jsonEncode({
      'model': model,
      'messages': payloadMessages,
      'stream': true,
    });

    final response = await _client.send(request);
    if (response.statusCode == 401) {
      throw GrokClientException('Unauthorized — sign in again', statusCode: 401);
    }
    if (response.statusCode == 403) {
      throw GrokClientException(
        'Access denied (403). Your SuperGrok / X Premium+ entitlement may not '
        'cover this API surface. Try again later or use an API key from console.x.ai.',
        statusCode: 403,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw GrokClientException(
        'Grok stream failed (${response.statusCode}): $body',
        statusCode: response.statusCode,
      );
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final sep = buffer.indexOf('\n');
        if (sep < 0) break;
        final line = buffer.substring(0, sep).trimRight();
        buffer = buffer.substring(sep + 1);
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices.first['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) yield content;
        } catch (_) {
          // Skip malformed SSE lines.
        }
      }
    }
  }
}
