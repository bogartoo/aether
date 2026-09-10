import 'package:flutter/foundation.dart';

import '../api/edge0_client.dart';
import '../auth/settings_store.dart';

enum ConnPhase {
  loading,
  disconnected,
  connecting,
  connected,
  error,
}

/// App-wide Edge0 connection + chat controller.
class HrtbrkrController extends ChangeNotifier {
  HrtbrkrController({
    SettingsStore? settingsStore,
    Edge0Client? client,
  })  : _store = settingsStore ?? SettingsStore(),
        _client = client ?? Edge0Client();

  final SettingsStore _store;
  final Edge0Client _client;

  ConnPhase phase = ConnPhase.loading;
  String? errorMessage;
  String baseUrl = kDefaultEdge0BaseUrl;
  String model = kDefaultEdge0Model;
  String servedModel = '';
  List<String> availableModels = List<String>.from(kEdge0Models);

  bool get isConnected => phase == ConnPhase.connected;

  final List<ChatMessage> messages = [];
  bool sending = false;

  void setModel(String next) {
    if (next == model) return;
    model = next;
    _store.saveModel(next);
    notifyListeners();
  }

  void setBaseUrl(String next) {
    final trimmed = next.trim();
    if (trimmed.isEmpty || trimmed == baseUrl) return;
    baseUrl = trimmed;
    _client.baseUrl = trimmed;
    notifyListeners();
  }

  static const systemPrompt =
      'You are HRTBRKR, a personal AI agent running on the user\'s device. '
      'You are powered by a local Edge0 language model — nothing leaves the machine. '
      'Be direct, capable, and helpful. Give full, useful answers.';

  Future<void> bootstrap() async {
    phase = ConnPhase.loading;
    notifyListeners();
    try {
      baseUrl = await _store.loadBaseUrl();
      model = await _store.loadModel();
      _client.baseUrl = baseUrl;
      final wasConnected = await _store.loadConnected();
      if (wasConnected) {
        await connect(silent: true);
      } else {
        phase = ConnPhase.disconnected;
      }
    } catch (e) {
      phase = ConnPhase.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> connect({bool silent = false}) async {
    errorMessage = null;
    phase = ConnPhase.connecting;
    notifyListeners();

    try {
      _client.baseUrl = baseUrl;
      final health = await _client.health();
      if (!health.ok) {
        throw Edge0ClientException('Edge0 reported unhealthy status');
      }
      servedModel = health.model;
      if (servedModel.isNotEmpty && model != servedModel) {
        // Prefer the model the server is actually serving.
        model = servedModel;
      }
      availableModels = await _client.listModels();
      if (!availableModels.contains(model) && availableModels.isNotEmpty) {
        model = availableModels.first;
      }

      await _store.saveBaseUrl(baseUrl);
      await _store.saveModel(model);
      await _store.saveConnected(true);

      phase = ConnPhase.connected;
      if (messages.isEmpty) {
        messages.add(
          ChatMessage(
            role: 'assistant',
            content:
                'HRTBRKR online. Local Edge0 · $model — your weights, your machine.',
          ),
        );
      }
    } catch (e) {
      await _store.saveConnected(false);
      phase = ConnPhase.disconnected;
      errorMessage = silent
          ? null
          : e.toString().replaceFirst('Edge0ClientException: ', '');
      if (!silent && errorMessage == null) {
        errorMessage = e.toString();
      }
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _store.saveConnected(false);
    messages.clear();
    servedModel = '';
    phase = ConnPhase.disconnected;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending || !isConnected) return;

    messages.add(ChatMessage(role: 'user', content: trimmed));
    final assistant =
        ChatMessage(role: 'assistant', content: '', streaming: true);
    messages.add(assistant);
    sending = true;
    notifyListeners();

    try {
      final forApi = messages
          .where((m) => !identical(m, assistant) && m.content.isNotEmpty)
          .toList();

      final buffer = StringBuffer();
      await for (final delta in _client.chatStream(
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
          messages: forApi,
          model: model,
          systemPrompt: systemPrompt,
        );
      }
    } on Edge0ClientException catch (e) {
      assistant.content = e.message;
    } catch (e) {
      assistant.content = 'Something went wrong: $e';
    } finally {
      assistant.streaming = false;
      sending = false;
      notifyListeners();
    }
  }
}
