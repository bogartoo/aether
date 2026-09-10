import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/edge0_client.dart';
import '../state/hrtbrkr_controller.dart';
import '../theme/hrtbrkr_logo.dart';
import '../theme/hrtbrkr_theme.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final TextEditingController _urlController;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    final ctrl = context.read<HrtbrkrController>();
    _urlController = TextEditingController(text: ctrl.baseUrl);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connect(HrtbrkrController ctrl) async {
    ctrl.setBaseUrl(_urlController.text);
    await ctrl.connect();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HrtbrkrController>();
    final connecting = ctrl.phase == ConnPhase.connecting;

    return Scaffold(
      body: Container(
        decoration: hrtbrkrBackdrop(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: Tween(begin: 0.72, end: 1.0).animate(
                        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                      ),
                      child: ScaleTransition(
                        scale: Tween(begin: 0.96, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _pulse,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: const Center(
                          child: HrtbrkrLogo(size: 88, iconSize: 42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'HRTBRKR',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 42,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your own Edge0 LLM.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 22,
                            color: HrtbrkrColors.ivory,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Runs a local Edge0 model on your machine — no cloud AI accounts, no API keys.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: HrtbrkrColors.mist,
                            fontSize: 15,
                          ),
                    ),
                    const Spacer(flex: 2),
                    if (ctrl.errorMessage != null) ...[
                      Text(
                        ctrl.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF8A80),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: connecting ? null : () => _connect(ctrl),
                      icon: connecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.power_settings_new_rounded),
                      label: Text(connecting ? 'Connecting…' : 'Connect to Edge0'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                      child: Text(
                        _showAdvanced ? 'Hide server settings' : 'Server settings',
                        style: const TextStyle(color: HrtbrkrColors.mist),
                      ),
                    ),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        enabled: !connecting,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: kDefaultEdge0BaseUrl,
                          labelText: 'Edge0 base URL',
                          filled: true,
                          fillColor: HrtbrkrColors.panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: ctrl.availableModels.contains(ctrl.model)
                            ? ctrl.model
                            : ctrl.availableModels.first,
                        dropdownColor: HrtbrkrColors.panel,
                        decoration: InputDecoration(
                          labelText: 'Model tier',
                          filled: true,
                          fillColor: HrtbrkrColors.panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: ctrl.availableModels
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m),
                              ),
                            )
                            .toList(),
                        onChanged: connecting
                            ? null
                            : (v) {
                                if (v != null) ctrl.setModel(v);
                              },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'On Android emulator use http://10.0.2.2:8000 to reach Edge0 on your Mac.',
                        style: TextStyle(
                          color: HrtbrkrColors.mist.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(flex: 1),
                    Text(
                      'Start Edge0 first: edge0 serve edge0-8b',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HrtbrkrColors.mist.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(
                            text: 'edge0 serve edge0-8b',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Command copied')),
                          );
                        }
                      },
                      child: const Text(
                        'Copy serve command',
                        style: TextStyle(color: HrtbrkrColors.mist, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
