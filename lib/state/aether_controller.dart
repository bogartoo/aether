import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/grok_client.dart';
import '../auth/auth_store.dart';
import '../auth/grok_oauth.dart';

enum AuthPhase {
  loading,
  signedOut,
  awaitingApproval,
  signedIn,
  error,
}

/// App-wide auth + chat + Imagine controller.
class AetherController extends ChangeNotifier {
  AetherController({
    AuthStore? authStore,
    GrokOAuth? oauth,
    GrokClient? client,
  })  : _store = authStore ?? AuthStore(),
        _oauth = oauth ?? GrokOAuth(),
        _client = client ?? GrokClient();

  final AuthStore _store;
  final GrokOAuth _oauth;
  final GrokClient _client;

  AuthPhase phase = AuthPhase.loading;
  String? errorMessage;
  GrokDeviceCode? pendingDevice;
  String pollStatus = '';
  bool _cancelPoll = false;

  GrokTokens? _tokens;
  String? _apiKey;

  bool get isSignedIn =>
      (_tokens != null && _tokens!.accessToken.isNotEmpty) ||
      (_apiKey != null && _apiKey!.isNotEmpty);

  bool get usingSubscription =>
      _tokens != null && (_apiKey == null || _apiKey!.isEmpty);

  final List<ChatMessage> messages = [];
  bool sending = false;
  bool imageMode = false;
  String model = kDefaultGrokModel;
  String imagineModel = kDefaultImagineModel;

  void setModel(String next) {
    if (next == model) return;
    model = next;
    notifyListeners();
  }

  void setImagineModel(String next) {
    if (next == imagineModel) return;
    imagineModel = next;
    notifyListeners();
  }

  void setImageMode(bool enabled) {
    if (imageMode == enabled) return;
    imageMode = enabled;
    notifyListeners();
  }

  static const systemPrompt =
      'You are Aether, a personal AI agent running on the user\'s device. '
      'You are powered by Grok via their SuperGrok / X Premium+ subscription '
      '(or an xAI API key). Be direct, capable, and helpful. '
      'When the user asks to create, draw, or generate an image, remind them '
      'they can toggle Imagine mode or open the Imagine studio.';

  Future<void> bootstrap() async {
    phase = AuthPhase.loading;
    notifyListeners();
    try {
      _tokens = await _store.loadTokens();
      _apiKey = await _store.loadApiKey();
      if (_tokens != null && _tokens!.isExpiringSoon) {
        try {
          _tokens = await _oauth.refresh(_tokens!.refreshToken);
          await _store.saveTokens(_tokens!);
        } catch (_) {
          await _store.clearTokens();
          _tokens = null;
        }
      }
      if (isSignedIn) {
        phase = AuthPhase.signedIn;
        if (messages.isEmpty) {
          messages.add(
            ChatMessage(
              role: 'assistant',
              content: usingSubscription
                  ? 'Aether online. Signed in with your Grok account — chat or flip Imagine to generate images.'
                  : 'Aether online. API key connected — chat or flip Imagine to generate images.',
            ),
          );
        }
      } else {
        phase = AuthPhase.signedOut;
      }
    } catch (e) {
      phase = AuthPhase.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> startGrokSignIn({bool openBrowser = true}) async {
    errorMessage = null;
    _cancelPoll = false;
    try {
      final device = await _oauth.requestDeviceCode();
      pendingDevice = device;
      phase = AuthPhase.awaitingApproval;
      pollStatus = 'Open the link and approve access';
      notifyListeners();

      if (openBrowser) {
        final uri = Uri.parse(device.browserUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      final tokens = await _oauth.pollForTokens(
        device,
        onStatus: (s) {
          pollStatus = s;
          notifyListeners();
        },
        shouldCancel: () => _cancelPoll,
      );

      _tokens = tokens;
      await _store.saveTokens(tokens);
      pendingDevice = null;
      phase = AuthPhase.signedIn;
      messages
        ..clear()
        ..add(
          ChatMessage(
            role: 'assistant',
            content:
                'Welcome. You\'re signed into Grok with your subscription. Chat freely, or open Imagine.',
          ),
        );
      notifyListeners();
    } catch (e) {
      if (_cancelPoll) {
        phase = AuthPhase.signedOut;
        pendingDevice = null;
        notifyListeners();
        return;
      }
      final raw = e.toString();
      if (kIsWeb &&
          (raw.contains('Failed to fetch') ||
              raw.contains('ClientException') ||
              raw.contains('XMLHttpRequest'))) {
        errorMessage =
            'Grok sign-in from the browser is blocked by xAI CORS. '
            'Use the Android / Windows app, or expand “Use API key instead”.';
      } else {
        errorMessage = raw;
      }
      pendingDevice = null;
      phase = AuthPhase.signedOut;
      notifyListeners();
    }
  }

  void cancelSignIn() {
    _cancelPoll = true;
    pendingDevice = null;
    phase = AuthPhase.signedOut;
    notifyListeners();
  }

  Future<void> signInWithApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) return;
    _apiKey = trimmed;
    await _store.saveApiKey(trimmed);
    phase = AuthPhase.signedIn;
    messages
      ..clear()
      ..add(
        ChatMessage(
          role: 'assistant',
          content: 'API key saved. Chat or flip Imagine to generate images.',
        ),
      );
    notifyListeners();
  }

  Future<void> signOut() async {
    _cancelPoll = true;
    await _store.clearAll();
    _tokens = null;
    _apiKey = null;
    messages.clear();
    pendingDevice = null;
    imageMode = false;
    phase = AuthPhase.signedOut;
    notifyListeners();
  }

  Future<String> _bearer() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) return _apiKey!;
    if (_tokens == null) {
      throw GrokClientException('Not signed in');
    }
    if (_tokens!.isExpiringSoon) {
      _tokens = await _oauth.refresh(_tokens!.refreshToken);
      await _store.saveTokens(_tokens!);
    }
    return _tokens!.accessToken;
  }

  bool looksLikeImageRequest(String text) {
    final lower = text.toLowerCase().trim();
    return lower.startsWith('/imagine ') ||
        lower.startsWith('imagine ') ||
        lower.startsWith('draw ') ||
        lower.startsWith('generate an image') ||
        lower.startsWith('generate image');
  }

  String imagePromptFrom(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('/imagine ')) return text.substring(9).trim();
    if (lower.startsWith('imagine ')) return text.substring(8).trim();
    if (lower.startsWith('draw ')) return text.substring(5).trim();
    if (lower.startsWith('generate an image')) {
      return text
          .replaceFirst(
            RegExp(r'^generate an image[:\s]*', caseSensitive: false),
            '',
          )
          .trim();
    }
    if (lower.startsWith('generate image')) {
      return text
          .replaceFirst(
            RegExp(r'^generate image[:\s]*', caseSensitive: false),
            '',
          )
          .trim();
    }
    return text.trim();
  }

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;

    if (imageMode || looksLikeImageRequest(trimmed)) {
      await generateImageInChat(trimmed);
      return;
    }

    messages.add(ChatMessage(role: 'user', content: trimmed));
    final assistant =
        ChatMessage(role: 'assistant', content: '', streaming: true);
    messages.add(assistant);
    sending = true;
    notifyListeners();

    try {
      final token = await _bearer();
      final forApi = messages
          .where((m) => !identical(m, assistant) && m.content.isNotEmpty)
          .where((m) => !m.hasImage)
          .toList();

      final buffer = StringBuffer();
      await for (final delta in _client.chatStream(
        accessToken: token,
        messages: forApi,
        model: model,
        systemPrompt: systemPrompt,
      )) {
        buffer.write(delta);
        assistant.content = buffer.toString();
        notifyListeners();
      }

      if (assistant.content.isEmpty) {
        assistant.content = await _client.chat(
          accessToken: token,
          messages: forApi,
          model: model,
          systemPrompt: systemPrompt,
        );
      }
    } on GrokClientException catch (e) {
      if (e.statusCode == 401) {
        assistant.content =
            'Session expired. Sign out and sign in with Grok again.';
      } else {
        assistant.content = e.message;
      }
    } catch (e) {
      assistant.content = 'Something went wrong: $e';
    } finally {
      assistant.streaming = false;
      sending = false;
      notifyListeners();
    }
  }

  Future<void> generateImageInChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;

    final prompt = imagePromptFrom(trimmed);
    messages.add(ChatMessage(role: 'user', content: trimmed));
    final assistant = ChatMessage(
      role: 'assistant',
      content: 'Imagining…',
      streaming: true,
    );
    messages.add(assistant);
    sending = true;
    notifyListeners();

    try {
      final token = await _bearer();
      final image = await _client.generateImage(
        accessToken: token,
        prompt: prompt,
        model: imagineModel,
        responseFormat: 'b64_json',
      );
      assistant.content = 'Here you go.';
      assistant.imageBase64 = image.b64Json;
      assistant.imageUrl = image.url;
    } on GrokClientException catch (e) {
      assistant.content = e.message;
    } catch (e) {
      assistant.content = 'Imagine failed: $e';
    } finally {
      assistant.streaming = false;
      sending = false;
      notifyListeners();
    }
  }

  /// Standalone Imagine studio call (does not append chat history).
  Future<GeneratedImage> generateStudioImage({
    required String prompt,
    String? aspectRatio,
  }) async {
    final token = await _bearer();
    return _client.generateImage(
      accessToken: token,
      prompt: prompt,
      model: imagineModel,
      aspectRatio: aspectRatio,
      responseFormat: 'b64_json',
    );
  }
}
