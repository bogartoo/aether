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

/// App-wide auth + chat controller.
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
  String model = kDefaultGrokModel;

  void setModel(String next) {
    if (next == model) return;
    model = next;
    notifyListeners();
  }

  static const systemPrompt =
      'You are Aether, a personal AI agent running on the user\'s device. '
      'You are powered by Grok via their SuperGrok / X Premium+ subscription. '
      'Be direct, capable, and helpful. Give full, useful answers.';

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
              content:
                  'Aether online. Signed in with your Grok account — subscription access, ready when you are.',
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
                'Welcome. You\'re signed into Grok with your subscription. Ask me anything.',
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
      errorMessage = e.toString();
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
      ..add(ChatMessage(role: 'assistant', content: 'API key saved. Aether is ready.'));
    notifyListeners();
  }

  Future<void> signOut() async {
    _cancelPoll = true;
    await _store.clearAll();
    _tokens = null;
    _apiKey = null;
    messages.clear();
    pendingDevice = null;
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

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;

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
}
