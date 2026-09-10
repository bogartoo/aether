import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Default Edge0 OpenAI-compatible server (see `edge0 serve`).
const kDefaultEdge0BaseUrl = 'http://127.0.0.1:8000';

/// On web, prefer same-origin so a demo host can proxy Edge0.
String defaultEdge0BaseUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty && origin != 'null') return origin;
  }
  return kDefaultEdge0BaseUrl;
}

/// Edge0 model tiers from the open release (Apple Silicon).
const kEdge0Models = <String>['edge0-8b', 'edge0-35b'];

/// Default local models when talking to Ollama / other OpenAI-compatible hosts.
const kLocalModels = <String>['llama3.2:3b', 'llama3.2:1b', 'qwen2.5:3b'];

const kDefaultEdge0Model = 'edge0-8b';
const kDefaultOllamaModel = 'llama3.2:3b';

/// Pick a sensible default model for the configured base URL.
String defaultModelForBaseUrl(String baseUrl) {
  final u = baseUrl.toLowerCase();
  if (u.contains('11434') || u.contains('ollama')) return kDefaultOllamaModel;
  return kDefaultEdge0Model;
}

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

class Edge0ClientException implements Exception {
  Edge0ClientException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class Edge0Health {
  Edge0Health({required this.ok, required this.model, this.raw});

  final bool ok;
  final String model;
  final Map<String, dynamic>? raw;
}

/// OpenAI-compatible client aimed at a local `edge0 serve` process.
class Edge0Client {
  Edge0Client({http.Client? client, String? baseUrl})
      : baseUrl = baseUrl ?? defaultEdge0BaseUrl(),
        _client = client ?? http.Client();

  final http.Client _client;
  String baseUrl;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'hrtbrkr/1.0',
      };

  /// Probe `GET /healthz` — Edge0 returns `{status, model}`.
  Future<Edge0Health> health({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final response = await _client
          .get(_uri('/healthz'), headers: _headers)
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Edge0ClientException(
          'Edge0 health check failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String? ?? '';
      final model = json['model'] as String? ?? '';
      return Edge0Health(
        ok: status == 'ok' || status.isNotEmpty,
        model: model,
        raw: json,
      );
    } on TimeoutException {
      throw Edge0ClientException(
        'No Edge0 server at $baseUrl — start it with `edge0 serve`.',
      );
    } on Edge0ClientException {
      rethrow;
    } catch (e) {
      throw Edge0ClientException(
        'Cannot reach Edge0 at $baseUrl. Is `edge0 serve` running?\n$e',
      );
    }
  }

  /// List models from `GET /v1/models` (falls back to known tiers).
  Future<List<String>> listModels() async {
    try {
      final response = await _client.get(_uri('/v1/models'), headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return List<String>.from(kEdge0Models);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? const [];
      final ids = data
          .map((e) => (e as Map<String, dynamic>)['id'] as String?)
          .whereType<String>()
          .toList();
      return ids.isEmpty ? List<String>.from(kEdge0Models) : ids;
    } catch (_) {
      return List<String>.from(kEdge0Models);
    }
  }

  Future<String> chat({
    required List<ChatMessage> messages,
    String model = kDefaultEdge0Model,
    String? systemPrompt,
    int maxTokens = 1024,
  }) async {
    final payloadMessages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toApi()),
    ];

    final response = await _client.post(
      _uri('/v1/chat/completions'),
      headers: _headers,
      body: jsonEncode({
        'model': model,
        'messages': payloadMessages,
        'stream': false,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Edge0ClientException(
        'Edge0 request failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Edge0ClientException('Empty response from Edge0');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw Edge0ClientException('Malformed Edge0 response');
    }
    return content;
  }

  /// Streaming chat; yields text deltas from SSE.
  Stream<String> chatStream({
    required List<ChatMessage> messages,
    String model = kDefaultEdge0Model,
    String? systemPrompt,
    int maxTokens = 1024,
  }) async* {
    final payloadMessages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toApi()),
    ];

    final request = http.Request('POST', _uri('/v1/chat/completions'));
    request.headers.addAll({
      ..._headers,
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode({
      'model': model,
      'messages': payloadMessages,
      'stream': true,
      'max_tokens': maxTokens,
    });

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw Edge0ClientException(
        'Edge0 stream failed (${response.statusCode}): $body',
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
          if (json['error'] != null) {
            final err = json['error'];
            final msg = err is Map ? err['message'] : err.toString();
            throw Edge0ClientException('Edge0 error: $msg');
          }
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices.first['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) yield content;
        } on Edge0ClientException {
          rethrow;
        } catch (_) {
          // Skip malformed SSE lines.
        }
      }
    }
  }
}
