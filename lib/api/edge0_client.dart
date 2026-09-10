import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Default Edge0 OpenAI-compatible server (see `edge0 serve`).
const kDefaultEdge0BaseUrl = 'http://127.0.0.1:8000';

/// On web, prefer same-origin so a demo host can proxy the LLM + images.
String defaultEdge0BaseUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty && origin != 'null') return origin;
  }
  return kDefaultEdge0BaseUrl;
}

/// Edge0 model tiers from the open release (Apple Silicon).
const kEdge0Models = <String>['edge0-8b', 'edge0-35b'];

/// Default local chat models (Ollama).
const kLocalModels = <String>['hrtbrkr', 'dolphin-phi', 'llama3.2:3b'];

const kDefaultEdge0Model = 'edge0-8b';
const kDefaultOllamaModel = 'hrtbrkr';

String defaultModelForBaseUrl(String baseUrl) {
  final u = baseUrl.toLowerCase();
  if (u.contains('11434') || u.contains('ollama') || kIsWeb) {
    return kDefaultOllamaModel;
  }
  return kDefaultEdge0Model;
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.streaming = false,
    this.imageBytes,
    this.imageUrl,
  });

  final String role; // user | assistant | system
  String content;
  bool streaming;
  Uint8List? imageBytes;
  String? imageUrl;

  bool get hasImage =>
      imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

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

class GeneratedImage {
  GeneratedImage({this.bytes, this.url, this.revisedPrompt});

  final Uint8List? bytes;
  final String? url;
  final String? revisedPrompt;
}

/// OpenAI-compatible client for local LLM + `/v1/images/generations`.
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
    // Ollama OpenAI API already includes /v1 in base sometimes.
    if (root.endsWith('/v1') && path.startsWith('/v1/')) {
      return Uri.parse('$root${path.substring(3)}');
    }
    return Uri.parse('$root$path');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'hrtbrkr/1.0',
      };

  Future<Edge0Health> health({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      // Prefer /healthz (our proxy / Edge0); fall back to /v1/models (raw Ollama).
      http.Response response;
      try {
        response = await _client
            .get(_uri('/healthz'), headers: _headers)
            .timeout(timeout);
      } catch (_) {
        response = await _client
            .get(_uri('/v1/models'), headers: _headers)
            .timeout(timeout);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Edge0ClientException(
          'Health check failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String? ?? '';
      var model = json['model'] as String? ?? '';
      if (model.isEmpty) {
        final data = json['data'] as List<dynamic>? ?? const [];
        if (data.isNotEmpty) {
          model = (data.first as Map<String, dynamic>)['id'] as String? ?? '';
        }
      }
      return Edge0Health(
        ok: status == 'ok' || status.isNotEmpty || model.isNotEmpty,
        model: model,
        raw: json,
      );
    } on TimeoutException {
      throw Edge0ClientException(
        'No local LLM at $baseUrl — start Ollama or Edge0.',
      );
    } on Edge0ClientException {
      rethrow;
    } catch (e) {
      throw Edge0ClientException(
        'Cannot reach local LLM at $baseUrl.\n$e',
      );
    }
  }

  Future<List<String>> listModels() async {
    try {
      final response = await _client.get(_uri('/v1/models'), headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return List<String>.from(kLocalModels);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? const [];
      final ids = data
          .map((e) => (e as Map<String, dynamic>)['id'] as String?)
          .whereType<String>()
          .toList();
      return ids.isEmpty ? List<String>.from(kLocalModels) : ids;
    } catch (_) {
      return List<String>.from(kLocalModels);
    }
  }

  Future<String> chat({
    required List<ChatMessage> messages,
    String model = kDefaultOllamaModel,
    String? systemPrompt,
    int maxTokens = 2048,
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
        'Chat failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Edge0ClientException('Empty response from model');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw Edge0ClientException('Malformed chat response');
    }
    return content;
  }

  Stream<String> chatStream({
    required List<ChatMessage> messages,
    String model = kDefaultOllamaModel,
    String? systemPrompt,
    int maxTokens = 2048,
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
        'Chat stream failed (${response.statusCode}): $body',
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
            throw Edge0ClientException('Model error: $msg');
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

  /// OpenAI-compatible image generation (`POST /v1/images/generations`).
  Future<GeneratedImage> generateImage({
    required String prompt,
    String size = '768x768',
  }) async {
    final response = await _client
        .post(
          _uri('/v1/images/generations'),
          headers: _headers,
          body: jsonEncode({
            'prompt': prompt,
            'size': size,
            'n': 1,
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Edge0ClientException(
        'Image generation failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) {
      throw Edge0ClientException('Empty image response');
    }
    final first = data.first as Map<String, dynamic>;
    final revised = first['revised_prompt'] as String?;
    final b64 = first['b64_json'] as String?;
    final url = first['url'] as String?;
    Uint8List? bytes;
    if (b64 != null && b64.isNotEmpty) {
      bytes = base64Decode(b64);
    } else if (url != null && url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma > 0) bytes = base64Decode(url.substring(comma + 1));
    }
    return GeneratedImage(bytes: bytes, url: url, revisedPrompt: revised);
  }
}
