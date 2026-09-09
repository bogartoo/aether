import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/settings_store.dart';
import '../services/xai_client.dart';
import '../theme/aether_theme.dart';
import '../widgets/broken_heart_logo.dart';
import 'image_studio_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final SettingsStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _uuid = const Uuid();
  late final AnimationController _pulse;

  final _messages = <ChatMessage>[];
  String _provider = 'Grok';
  bool _connected = false;
  bool _busy = false;
  bool _imageMode = false;

  static const _providers = ['Grok', 'Ollama (local)', 'Claude', 'Gemini'];

  static const _systemPrompt =
      'You are Aether — a personal hybrid AI agent with no artificial chatter limits. '
      'You are powered by Grok when connected. Be direct, capable, and useful. '
      'When the user asks to create, draw, or generate an image, remind them they can '
      'toggle Imagine mode or open the Imagine studio.';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final provider = await widget.store.getProvider();
    final hasKey = await widget.store.hasApiKey;
    if (!mounted) return;
    setState(() {
      _provider = _providers.contains(provider) ? provider : 'Grok';
      _connected = hasKey;
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.aether,
          text: hasKey
              ? 'Aether online. Grok connected — chat freely, or flip Imagine to generate images.'
              : 'Aether online. Connect your Grok / xAI key in Settings to unlock unlimited personal chat + Imagine.',
        ),
      );
    });
    if (!hasKey && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connect your xAI key to start testing Grok + Imagine.'),
            action: SnackBarAction(
              label: 'Connect',
              onPressed: _openSettings,
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(store: widget.store),
      ),
    );
    if (changed == true && mounted) {
      final hasKey = await widget.store.hasApiKey;
      setState(() => _connected = hasKey);
    }
  }

  Future<void> _openImagine() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageStudioScreen(store: widget.store),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: text,
    );
    setState(() {
      _messages.add(userMsg);
      _controller.clear();
      _busy = true;
    });
    _scrollToEnd();

    if (_imageMode || _looksLikeImageRequest(text)) {
      await _generateImageReply(text);
      return;
    }

    if (_provider != 'Grok') {
      setState(() {
        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.aether,
            text:
                '[$_provider] Provider bridge is scaffolded. Switch to Grok for live personal AI + Imagine.',
          ),
        );
        _busy = false;
      });
      _scrollToEnd();
      return;
    }

    final key = await widget.store.getApiKey();
    if (key == null || key.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.aether,
            text:
                'No xAI key yet. Open Settings (broken heart menu → key) and paste your key from console.x.ai.',
          ),
        );
        _busy = false;
      });
      _scrollToEnd();
      return;
    }

    final replyId = _uuid.v4();
    setState(() {
      _messages.add(
        ChatMessage(
          id: replyId,
          role: ChatRole.aether,
          text: '',
          isStreaming: true,
        ),
      );
    });

    try {
      final model = await widget.store.getGrokModel();
      final client = XaiClient(apiKey: key);
      final history = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        ..._messages
            .where((m) => m.role != ChatRole.system && m.id != replyId)
            .where((m) => m.text.isNotEmpty)
            .map(
              (m) => {
                'role': m.role == ChatRole.user ? 'user' : 'assistant',
                'content': m.text,
              },
            ),
      ];

      final buffer = StringBuffer();
      await for (final delta in client.chatStream(
        messages: history,
        model: model,
      )) {
        buffer.write(delta);
        if (!mounted) return;
        _patchMessage(replyId, text: buffer.toString(), streaming: true);
        _scrollToEnd();
      }
      if (!mounted) return;
      _patchMessage(
        replyId,
        text: buffer.isEmpty ? '(empty reply from Grok)' : buffer.toString(),
        streaming: false,
      );
    } on XaiException catch (e) {
      _patchMessage(replyId, text: e.message, streaming: false);
    } catch (e) {
      _patchMessage(replyId, text: 'Error: $e', streaming: false);
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  bool _looksLikeImageRequest(String text) {
    final lower = text.toLowerCase();
    return lower.startsWith('/imagine ') ||
        lower.startsWith('imagine ') ||
        lower.startsWith('draw ') ||
        lower.startsWith('generate an image') ||
        lower.startsWith('generate image');
  }

  String _imagePromptFrom(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('/imagine ')) return text.substring(9).trim();
    if (lower.startsWith('imagine ')) return text.substring(8).trim();
    if (lower.startsWith('draw ')) return text.substring(5).trim();
    if (lower.startsWith('generate an image')) {
      return text.replaceFirst(RegExp(r'^generate an image[:\s]*', caseSensitive: false), '').trim();
    }
    if (lower.startsWith('generate image')) {
      return text.replaceFirst(RegExp(r'^generate image[:\s]*', caseSensitive: false), '').trim();
    }
    return text;
  }

  Future<void> _generateImageReply(String text) async {
    final key = await widget.store.getApiKey();
    if (key == null || key.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.aether,
            text: 'Connect your xAI key in Settings to use Imagine.',
          ),
        );
        _busy = false;
      });
      return;
    }

    final replyId = _uuid.v4();
    setState(() {
      _messages.add(
        ChatMessage(
          id: replyId,
          role: ChatRole.aether,
          text: 'Imagining…',
          isStreaming: true,
        ),
      );
    });
    _scrollToEnd();

    try {
      final model = await widget.store.getImagineModel();
      final client = XaiClient(apiKey: key);
      final image = await client.generateImage(
        prompt: _imagePromptFrom(text),
        model: model,
        responseFormat: 'b64_json',
      );
      if (!mounted) return;
      _patchMessage(
        replyId,
        text: 'Here you go.',
        imageBase64: image.b64Json,
        imageUrl: image.url,
        streaming: false,
      );
    } on XaiException catch (e) {
      _patchMessage(replyId, text: e.message, streaming: false);
    } catch (e) {
      _patchMessage(replyId, text: 'Imagine failed: $e', streaming: false);
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _patchMessage(
    String id, {
    String? text,
    String? imageUrl,
    String? imageBase64,
    bool? streaming,
  }) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i < 0) return;
    setState(() {
      _messages[i] = _messages[i].copyWith(
        text: text,
        imageUrl: imageUrl,
        imageBase64: imageBase64,
        isStreaming: streaming,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF1A0B14),
              Color(0xFF0D2B24),
              Color(0xFF061018),
            ],
            stops: [0, 0.35, 0.7, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                provider: _provider,
                providers: _providers,
                connected: _connected,
                pulse: _pulse,
                onProvider: (v) async {
                  setState(() => _provider = v);
                  await widget.store.setProvider(v);
                },
                onSettings: _openSettings,
                onImagine: _openImagine,
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                ),
              ),
              _Composer(
                controller: _controller,
                busy: _busy,
                imageMode: _imageMode,
                onToggleImage: () => setState(() => _imageMode = !_imageMode),
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.provider,
    required this.providers,
    required this.connected,
    required this.pulse,
    required this.onProvider,
    required this.onSettings,
    required this.onImagine,
  });

  final String provider;
  final List<String> providers;
  final bool connected;
  final AnimationController pulse;
  final ValueChanged<String> onProvider;
  final VoidCallback onSettings;
  final VoidCallback onImagine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSettings,
            child: FadeTransition(
              opacity: Tween(begin: 0.75, end: 1.0).animate(pulse),
              child: const BrokenHeartLogo(size: 42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AETHER',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected ? AetherColors.teal : AetherColors.mist,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connected ? 'Grok ready · Imagine on' : 'Connect Grok key',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AetherColors.mist,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Imagine studio',
            onPressed: onImagine,
            icon: const Icon(Icons.image_outlined, color: AetherColors.heart),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider,
              dropdownColor: AetherColors.panel,
              style: const TextStyle(color: AetherColors.teal, fontSize: 13),
              items: providers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onProvider(v);
              },
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isYou = message.role == ChatRole.user;
    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isYou
              ? AetherColors.teal.withValues(alpha: 0.14)
              : AetherColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isYou
                ? AetherColors.teal.withValues(alpha: 0.35)
                : AetherColors.panelEdge,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Text(
                message.text + (message.isStreaming ? ' ▍' : ''),
                style: const TextStyle(height: 1.4, fontSize: 15),
              ),
            if (message.hasImage) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: message.imageBase64 != null
                    ? Image.memory(
                        base64Decode(message.imageBase64!),
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        message.imageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.imageMode,
    required this.onToggleImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final bool imageMode;
  final VoidCallback onToggleImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Row(
        children: [
          Tooltip(
            message: imageMode ? 'Imagine mode on' : 'Imagine mode',
            child: IconButton.filledTonal(
              onPressed: onToggleImage,
              style: IconButton.styleFrom(
                backgroundColor: imageMode
                    ? AetherColors.heart.withValues(alpha: 0.25)
                    : AetherColors.panel,
                foregroundColor:
                    imageMode ? AetherColors.heart : AetherColors.mist,
              ),
              icon: Icon(
                imageMode ? Icons.image : Icons.image_outlined,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              enabled: !busy,
              decoration: InputDecoration(
                hintText: imageMode
                    ? 'Describe an image to Imagine…'
                    : 'Message Aether…',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : onSend,
            style: FilledButton.styleFrom(
              backgroundColor:
                  imageMode ? AetherColors.heart : AetherColors.teal,
              foregroundColor: imageMode ? Colors.white : Colors.black,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(imageMode ? Icons.auto_awesome : Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
