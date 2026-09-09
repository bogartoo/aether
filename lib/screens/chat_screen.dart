import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/grok_client.dart';
import '../state/aether_controller.dart';
import '../theme/aether_logo.dart';
import '../theme/aether_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(AetherController ctrl) async {
    final text = _controller.text;
    _controller.clear();
    // Scroll as tokens arrive.
    void listener() => _scrollToEnd();
    ctrl.addListener(listener);
    try {
      await ctrl.sendUserMessage(text);
    } finally {
      ctrl.removeListener(listener);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AetherController>();

    return Scaffold(
      body: Container(
        decoration: aetherBackdrop(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const AetherLogo(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AETHER',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            ctrl.usingSubscription
                                ? 'Grok · subscription'
                                : 'Grok · API key',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AetherColors.mist,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: AetherColors.panel,
                      onSelected: (v) async {
                        if (v == 'signout') await ctrl.signOut();
                        if (v.startsWith('model:')) {
                          ctrl.setModel(v.substring(6));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'model:grok-4',
                          child: Text('Model: grok-4'),
                        ),
                        const PopupMenuItem(
                          value: 'model:grok-3',
                          child: Text('Model: grok-3'),
                        ),
                        const PopupMenuItem(
                          value: 'model:grok-3-mini',
                          child: Text('Model: grok-3-mini'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'signout',
                          child: Text('Sign out'),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert, color: AetherColors.mist),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: ctrl.messages.length,
                  itemBuilder: (context, i) {
                    final m = ctrl.messages[i];
                    return _MessageBubble(message: m);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !ctrl.sending,
                        onSubmitted: (_) => _send(ctrl),
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Message Aether…',
                          filled: true,
                          fillColor: AetherColors.panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: ctrl.sending ? null : () => _send(ctrl),
                      style: FilledButton.styleFrom(
                        backgroundColor: AetherColors.mint,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AetherColors.mint.withValues(alpha: 0.4),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                      ),
                      child: ctrl.sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isYou = message.role == 'user';
    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isYou
              ? AetherColors.mint.withValues(alpha: 0.15)
              : AetherColors.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isYou
                ? AetherColors.mint.withValues(alpha: 0.35)
                : AetherColors.border,
          ),
        ),
        child: SelectableText(
          message.content.isEmpty && message.streaming ? '…' : message.content,
          style: const TextStyle(height: 1.4, fontSize: 15),
        ),
      ),
    );
  }
}
