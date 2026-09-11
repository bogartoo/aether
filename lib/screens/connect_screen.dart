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
      duration: const Duration(milliseconds: 2600),
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: Tween(begin: 0.82, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _pulse,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: ScaleTransition(
                        scale: Tween(begin: 0.96, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _pulse,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: const HrtbrkrLogo(size: 100, iconSize: 48),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'HRTBRKR',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 40,
                                  letterSpacing: 6,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your model. Your rules.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: HrtbrkrColors.mute,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const Spacer(flex: 2),
                    if (ctrl.errorMessage != null) ...[
                      Text(
                        ctrl.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: HrtbrkrColors.danger,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: connecting ? null : () => _connect(ctrl),
                        child: connecting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Connect'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                      child: Text(
                        _showAdvanced ? 'Hide settings' : 'Settings',
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: _showAdvanced
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _urlController,
                                    enabled: !connecting,
                                    keyboardType: TextInputType.url,
                                    decoration: const InputDecoration(
                                      labelText: 'Server URL',
                                      hintText: kDefaultEdge0BaseUrl,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    // ignore: deprecated_member_use
                                    value: ctrl.availableModels
                                            .contains(ctrl.model)
                                        ? ctrl.model
                                        : ctrl.availableModels.first,
                                    dropdownColor: HrtbrkrColors.raised,
                                    decoration: const InputDecoration(
                                      labelText: 'Model',
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
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          const ClipboardData(
                                            text: 'ollama run hrtbrkr',
                                          ),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Copied'),
                                              backgroundColor:
                                                  HrtbrkrColors.raised,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 16,
                                        color: HrtbrkrColors.pink,
                                      ),
                                      label: const Text(
                                        'Copy ollama run hrtbrkr',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const Spacer(flex: 2),
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
