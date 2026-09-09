import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/settings_store.dart';
import '../services/xai_client.dart';
import '../theme/aether_theme.dart';
import '../widgets/broken_heart_logo.dart';

/// Dedicated Imagine studio for Grok image generation.
class ImageStudioScreen extends StatefulWidget {
  const ImageStudioScreen({super.key, required this.store});

  final SettingsStore store;

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  final _prompt = TextEditingController();
  String _aspect = '1:1';
  bool _busy = false;
  String? _error;
  GeneratedImage? _result;

  static const _aspects = ['auto', '1:1', '16:9', '9:16', '4:3', '3:4', '3:2', '2:3'];

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) return;

    final key = await widget.store.getApiKey();
    if (key == null || key.isEmpty) {
      setState(() => _error = 'Add your xAI API key in Settings first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final model = await widget.store.getImagineModel();
      final client = XaiClient(apiKey: key);
      final image = await client.generateImage(
        prompt: prompt,
        model: model,
        aspectRatio: _aspect == 'auto' ? null : _aspect,
        responseFormat: 'b64_json',
      );
      if (!mounted) return;
      setState(() {
        _result = image;
        _busy = false;
      });
    } on XaiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF140A12), Color(0xFF0A1628), Color(0xFF061018)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const BrokenHeartLogo(size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Imagine',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      'Grok baked-in',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AetherColors.heart,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Text(
                      'Describe anything. Aether calls Grok Imagine directly.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AetherColors.mist,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _prompt,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'A fractured glass heart floating in deep space…',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _aspects.map((a) {
                        final selected = a == _aspect;
                        return ChoiceChip(
                          label: Text(a),
                          selected: selected,
                          onSelected: (_) => setState(() => _aspect = a),
                          selectedColor: AetherColors.heart.withValues(alpha: 0.35),
                          labelStyle: TextStyle(
                            color: selected ? AetherColors.foam : AetherColors.mist,
                          ),
                          backgroundColor: AetherColors.panel,
                          side: BorderSide(
                            color: selected
                                ? AetherColors.heart
                                : AetherColors.panelEdge,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _busy ? null : _generate,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_busy ? 'Generating…' : 'Generate image'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AetherColors.heart,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFF8A8A)),
                      ),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _result!.b64Json != null
                            ? Image.memory(
                                base64Decode(_result!.b64Json!),
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                _result!.url!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ],
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
