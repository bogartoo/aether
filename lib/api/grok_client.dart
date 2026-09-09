import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const kGrokApiBase = 'https://api.x.ai/v1';
const kDefaultGrokModel = 'grok-4';
const kDefaultImagineModel = 'grok-imagine-image-2.0';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.streaming = false,
    this.imageUrl,
    this.imageBase64,
  });

  final String role; // user | assistant | system
  String content;
  bool streaming;
  String? imageUrl;
  String? imageBase64;

  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty);

  Map<String, String> toApi() => {'role': role, 'content': content};
}

class GeneratedImage {
  GeneratedImage({this.url, this.b64Json});
  final String? url;
  final String? b64Json;
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

  Map<String, String> _headers(String accessToken, {required String accept}) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': accept,
        'User-Agent': 'aether/1.0.2',
      };

  String _friendlyError(int status, String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final err = data['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
      if (err is String) return err;
    } catch (_) {}
    if (status == 401) {
      return 'Unauthorized — sign in again or refresh your API key.';
    }
    if (status == 403) {
      return 'Access denied (403). Your SuperGrok / X Premium+ entitlement may not '
          'cover this API surface. Try an API key from console.x.ai.';
    }
    if (status == 429) {
      return 'Rate limited by xAI. Try again in a moment.';
    }
    return 'Grok request failed ($status).';
  }

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
      headers: _headers(accessToken, accept: 'application/json'),
      body: jsonEncode({
        'model': model,
        'messages': payloadMessages,
        'stream': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GrokClientException(
        _friendlyError(response.statusCode, response.body),
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
    request.headers.addAll(_headers(accessToken, accept: 'text/event-stream'));
    request.body = jsonEncode({
      'model': model,
      'messages': payloadMessages,
      'stream': true,
    });

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw GrokClientException(
        _friendlyError(response.statusCode, body),
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

  /// Grok Imagine — text → image.
  Future<GeneratedImage> generateImage({
    required String accessToken,
    required String prompt,
    String model = kDefaultImagineModel,
    String? aspectRatio,
    int n = 1,
    String responseFormat = 'b64_json',
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'n': n,
      'response_format': responseFormat,
    };
    if (aspectRatio != null && aspectRatio.isNotEmpty) {
      body['aspect_ratio'] = aspectRatio;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/images/generations'),
      headers: _headers(accessToken, accept: 'application/json'),
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GrokClientException(
        _friendlyError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final images = data['data'] as List<dynamic>?;
    if (images == null || images.isEmpty) {
      throw GrokClientException('Imagine returned no images.');
    }
    final first = images.first as Map<String, dynamic>;
    return GeneratedImage(
      url: first['url'] as String?,
      b64Json: first['b64_json'] as String?,
    );
  }
}
