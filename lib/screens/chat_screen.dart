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
        duration: const Duration(milliseconds: 260),
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
      backgroundColor: HrtbrkrColors.black,
      body: Container(
        decoration: hrtbrkrBackdrop(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 10, 12),
                child: Row(
                  children: [
                    const HrtbrkrLogo(size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HRTBRKR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontSize: 18,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: HrtbrkrColors.pink,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: HrtbrkrColors.mute,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: HrtbrkrColors.raised,
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
                                ctrl.model == m ? 'Chat · $m ✓' : 'Chat · $m',
                              ),
                            ),
                          ),
                          const PopupMenuDivider(),
                          ...imgModels.map((m) {
                            final id = '${m['id']}';
                            final name = '${m['label'] ?? id}';
                            return PopupMenuItem(
                              value: 'img:$id',
                              child: Text(
                                ctrl.imageModel == id
                                    ? 'Image · $name ✓'
                                    : 'Image · $name',
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
                      icon: const Icon(
                        Icons.more_horiz,
                        color: HrtbrkrColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: HrtbrkrColors.pink.withValues(alpha: 0.22),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                  itemCount: ctrl.messages.length,
                  itemBuilder: (context, i) {
                    return _MessageBubble(message: ctrl.messages[i]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: HrtbrkrColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _imageMode
                          ? HrtbrkrColors.pink.withValues(alpha: 0.6)
                          : HrtbrkrColors.line,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: _imageMode ? 'Image mode on' : 'Image mode',
                        onPressed: ctrl.sending
                            ? null
                            : () => setState(() => _imageMode = !_imageMode),
                        icon: Icon(
                          Icons.image_outlined,
                          color: _imageMode
                              ? HrtbrkrColors.pink
                              : HrtbrkrColors.mute,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !ctrl.sending,
                          onSubmitted: (_) => _send(ctrl),
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 15, height: 1.35),
                          decoration: InputDecoration(
                            hintText: _imageMode
                                ? 'Describe an image…'
                                : 'Message…',
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Material(
                        color: ctrl.sending
                            ? HrtbrkrColors.pink.withValues(alpha: 0.35)
                            : HrtbrkrColors.pink,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: ctrl.sending ? null : () => _send(ctrl),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: ctrl.sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(
                                      _imageMode
                                          ? Icons.auto_awesome
                                          : Icons.arrow_upward_rounded,
                                      color: Colors.black,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
        padding: EdgeInsets.symmetric(
          horizontal: isYou ? 14 : 4,
          vertical: isYou ? 12 : 6,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isYou ? HrtbrkrColors.pinkDim : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isYou ? 16 : 4),
            bottomRight: Radius.circular(isYou ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                          style: TextStyle(color: HrtbrkrColors.mute),
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
                style: TextStyle(
                  height: 1.45,
                  fontSize: 15,
                  color: isYou
                      ? HrtbrkrColors.white
                      : HrtbrkrColors.white.withValues(alpha: 0.92),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
