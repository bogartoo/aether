import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/edge0_client.dart';
import '../state/hrtbrkr_controller.dart';
import '../theme/hrtbrkr_logo.dart';
import '../theme/hrtbrkr_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _imageMode = false;

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

  Future<void> _send(HrtbrkrController ctrl) async {
    final text = _controller.text;
    final asImage = _imageMode;
    _controller.clear();
    if (asImage) setState(() => _imageMode = false);
    void listener() => _scrollToEnd();
    ctrl.addListener(listener);
    try {
      await ctrl.sendUserMessage(text, forceImage: asImage);
    } finally {
      ctrl.removeListener(listener);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HrtbrkrController>();
    final label = ctrl.servedModel.isNotEmpty ? ctrl.servedModel : ctrl.model;

    return Scaffold(
      body: Container(
        decoration: hrtbrkrBackdrop(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const HrtbrkrLogo(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HRTBRKR',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            ctrl.imageHq
                                ? 'Uncensored · $label · ${ctrl.imageModel}'
                                : 'Uncensored · $label · images need API key',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HrtbrkrColors.mist,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: HrtbrkrColors.panel,
                      onSelected: (v) async {
                        if (v == 'disconnect') await ctrl.disconnect();
                        if (v.startsWith('model:')) {
                          ctrl.setModel(v.substring(6));
                        }
                        if (v.startsWith('img:')) {
                          ctrl.setImageModel(v.substring(4));
                        }
                      },
                      itemBuilder: (context) {
                        final models = ctrl.availableModels.isEmpty
                            ? <String>[...kLocalModels, ...kEdge0Models]
                            : ctrl.availableModels;
                        final imgModels = ctrl.imageModels.isEmpty
                            ? [
                                for (final id in Edge0Client.kImageModels)
                                  {'id': id, 'label': id},
                              ]
                            : ctrl.imageModels;
                        return [
                          ...models.map(
                            (m) => PopupMenuItem(
                              value: 'model:$m',
                              child: Text(
                                ctrl.model == m ? 'Chat: $m ✓' : 'Chat: $m',
                              ),
                            ),
                          ),
                          const PopupMenuDivider(),
                          ...imgModels.map((m) {
                            final id = '${m['id']}';
                            final label = '${m['label'] ?? id}';
                            return PopupMenuItem(
                              value: 'img:$id',
                              child: Text(
                                ctrl.imageModel == id
                                    ? 'Image: $label ✓'
                                    : 'Image: $label',
                              ),
                            );
                          }),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'disconnect',
                            child: Text('Disconnect'),
                          ),
                        ];
                      },
                      icon: const Icon(Icons.more_vert, color: HrtbrkrColors.mist),
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _imageMode ? 'Image mode on' : 'Generate image',
                      onPressed: ctrl.sending
                          ? null
                          : () => setState(() => _imageMode = !_imageMode),
                      icon: Icon(
                        Icons.image_outlined,
                        color: _imageMode
                            ? HrtbrkrColors.mint
                            : HrtbrkrColors.mist,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !ctrl.sending,
                        onSubmitted: (_) => _send(ctrl),
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: _imageMode
                              ? 'Image prompt…'
                              : 'Message HRTBRKR… (/imagine …)',
                          filled: true,
                          fillColor: HrtbrkrColors.panel,
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
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: ctrl.sending ? null : () => _send(ctrl),
                      style: FilledButton.styleFrom(
                        backgroundColor: HrtbrkrColors.mint,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            HrtbrkrColors.mint.withValues(alpha: 0.4),
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
                          : Icon(
                              _imageMode ? Icons.auto_awesome : Icons.send_rounded,
                            ),
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
              ? HrtbrkrColors.mint.withValues(alpha: 0.15)
              : HrtbrkrColors.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isYou
                ? HrtbrkrColors.mint.withValues(alpha: 0.35)
                : HrtbrkrColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: message.imageBytes != null
                    ? Image.memory(
                        message.imageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Image.network(
                        message.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, error, stack) => const Text(
                          'Image failed to load',
                          style: TextStyle(color: HrtbrkrColors.mist),
                        ),
                      ),
              ),
              if (message.content.isNotEmpty) const SizedBox(height: 10),
            ],
            if (message.content.isNotEmpty || message.streaming)
              SelectableText(
                message.content.isEmpty && message.streaming
                    ? '…'
                    : message.content,
                style: const TextStyle(height: 1.4, fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }
}
