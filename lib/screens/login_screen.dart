import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/aether_controller.dart';
import '../theme/aether_logo.dart';
import '../theme/aether_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _apiKeyController = TextEditingController();
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AetherController>();
    final awaiting = ctrl.phase == AuthPhase.awaitingApproval;
    final device = ctrl.pendingDevice;

    return Scaffold(
      body: Container(
        decoration: aetherBackdrop(),
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
                        child: Center(
                          child: AetherLogo(size: 88, iconSize: 42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'AETHER',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 42,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your personal Grok.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 22,
                            color: AetherColors.ivory,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in with SuperGrok or X Premium+ — subscription access, not metered API keys.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AetherColors.mist,
                            fontSize: 15,
                          ),
                    ),
                    const Spacer(flex: 2),
                    if (ctrl.errorMessage != null) ...[
                      Text(
                        ctrl.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!awaiting) ...[
                      FilledButton.icon(
                        onPressed: () => ctrl.startGrokSignIn(),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in with Grok'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _showApiKey = !_showApiKey),
                        child: Text(
                          _showApiKey ? 'Hide API key option' : 'Use API key instead',
                          style: const TextStyle(color: AetherColors.mist),
                        ),
                      ),
                      if (_showApiKey) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'xai-… API key',
                            filled: true,
                            fillColor: AetherColors.panel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () =>
                              ctrl.signInWithApiKey(_apiKeyController.text),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AetherColors.mint,
                            side: const BorderSide(color: AetherColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Continue with API key'),
                        ),
                      ],
                    ] else if (device != null) ...[
                      _DeviceCodeCard(
                        userCode: device.userCode,
                        verificationUri: device.verificationUri,
                        browserUrl: device.browserUrl,
                        status: ctrl.pollStatus,
                        onCancel: ctrl.cancelSignIn,
                        onOpen: () => launchUrl(
                          Uri.parse(device.browserUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                    const Spacer(flex: 1),
                    Text(
                      'Tokens stay on this device. Aether never sees your password.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AetherColors.mist.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 20),
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

class _DeviceCodeCard extends StatelessWidget {
  const _DeviceCodeCard({
    required this.userCode,
    required this.verificationUri,
    required this.browserUrl,
    required this.status,
    required this.onCancel,
    required this.onOpen,
  });

  final String userCode;
  final String verificationUri;
  final String browserUrl;
  final String status;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Approve on any device',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AetherColors.mint,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        Material(
          color: AetherColors.panel,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: userCode));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    userCode,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 36,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w700,
                          color: AetherColors.mint,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap to copy',
                    style: TextStyle(color: AetherColors.mist, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          verificationUri,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AetherColors.mist, fontSize: 13),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Open approval page'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status,
                style: const TextStyle(color: AetherColors.mist, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel', style: TextStyle(color: AetherColors.mist)),
            ),
          ],
        ),
      ],
    );
  }
}
