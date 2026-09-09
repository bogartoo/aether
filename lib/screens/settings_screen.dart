import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings_store.dart';
import '../theme/aether_theme.dart';
import '../widgets/broken_heart_logo.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final SettingsStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyController = TextEditingController();
  String _model = 'grok-4-1-fast-reasoning';
  String _imagineModel = 'grok-imagine-image-2.0';
  bool _obscure = true;
  bool _saving = false;
  bool _hasKey = false;

  static const _chatModels = [
    'grok-4-1-fast-reasoning',
    'grok-4-1-fast-non-reasoning',
    'grok-4',
    'grok-3',
    'grok-3-mini',
  ];

  static const _imagineModels = [
    'grok-imagine-image-2.0',
    'grok-imagine-image',
    'grok-imagine-image-quality',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await widget.store.getApiKey();
    final model = await widget.store.getGrokModel();
    final imagine = await widget.store.getImagineModel();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null && key.isNotEmpty;
      _keyController.text = key ?? '';
      _model = _chatModels.contains(model) ? model : _chatModels.first;
      _imagineModel =
          _imagineModels.contains(imagine) ? imagine : _imagineModels.first;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.store.setApiKey(_keyController.text);
    await widget.store.setGrokModel(_model);
    await widget.store.setImagineModel(_imagineModel);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _hasKey = _keyController.text.trim().isNotEmpty;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grok credentials saved locally.')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _openConsole() async {
    final uri = Uri.parse('https://console.x.ai');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF1A0A12), Color(0xFF061018)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const BrokenHeartLogo(size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Grok account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Sign in with your xAI API key for unlimited personal Grok — chat plus Imagine image generation.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AetherColors.mist,
                    ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'API key',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _keyController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'xai-…',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _openConsole,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('console.x.ai'),
                        ),
                        const Spacer(),
                        if (_hasKey)
                          Text(
                            'Key on device',
                            style: TextStyle(
                              color: AetherColors.teal.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Chat model',
                child: DropdownButtonFormField<String>(
                  initialValue: _model,
                  dropdownColor: AetherColors.panel,
                  items: _chatModels
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _model = v!),
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Imagine model',
                child: DropdownButtonFormField<String>(
                  initialValue: _imagineModel,
                  dropdownColor: AetherColors.panel,
                  items: _imagineModels
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _imagineModel = v!),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AetherColors.heart,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_saving ? 'Saving…' : 'Save & connect'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _keyController.text),
                  );
                },
                child: const Text('Copy key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            color: AetherColors.mist,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
