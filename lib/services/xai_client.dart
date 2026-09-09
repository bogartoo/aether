import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class XaiException implements Exception {
  XaiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class GeneratedImage {
  GeneratedImage({this.url, this.b64Json});
  final String? url;
  final String? b64Json;
}

/// Thin xAI / Grok client — chat completions + Imagine image generation.
class XaiClient {
  XaiClient({
    required this.apiKey,
    http.Client? httpClient,
    this.baseUrl = 'https://api.x.ai/v1',
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  /// Non-streaming chat completion.
  Future<String> chat({
    required List<Map<String, String>> messages,
    required String model,
    double temperature = 0.7,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await _http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'stream': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw XaiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw XaiException('Grok returned an empty response.');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    return (message?['content'] as String?)?.trim() ?? '';
  }

  /// Streaming chat — yields incremental text deltas.
  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    required String model,
    double temperature = 0.7,
  }) async* {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers)
      ..body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'stream': true,
      });

    final streamed = await _http.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw XaiException(
        _errorMessageFromBody(body, streamed.statusCode),
        statusCode: streamed.statusCode,
      );
    }

    final lines = streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty || !line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') break;
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = choices.first['delta'] as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } catch (_) {
        // Skip malformed SSE chunks.
      }
    }
  }

  /// Grok Imagine — text → image.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    String? aspectRatio,
    int n = 1,
    String responseFormat = 'url',
  }) async {
    final uri = Uri.parse('$baseUrl/images/generations');
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'n': n,
      'response_format': responseFormat,
    };
    if (aspectRatio != null && aspectRatio.isNotEmpty) {
      body['aspect_ratio'] = aspectRatio;
    }

    final response = await _http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw XaiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final images = data['data'] as List<dynamic>?;
    if (images == null || images.isEmpty) {
      throw XaiException('Imagine returned no images.');
    }
    final first = images.first as Map<String, dynamic>;
    return GeneratedImage(
      url: first['url'] as String?,
      b64Json: first['b64_json'] as String?,
    );
  }

  String _errorMessage(http.Response response) =>
      _errorMessageFromBody(response.body, response.statusCode);

  String _errorMessageFromBody(String body, int status) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final err = data['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
      if (err is String) return err;
    } catch (_) {}
    if (status == 401) {
      return 'Invalid xAI API key. Open Settings and paste a key from console.x.ai.';
    }
    if (status == 429) {
      return 'Rate limited by xAI. Try again in a moment.';
    }
    return 'xAI request failed ($status).';
  }

  void close() => _http.close();
}
