import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'state/aether_controller.dart';
import 'theme/aether_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AetherRoot());
}

class AetherRoot extends StatelessWidget {
  const AetherRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AetherController()..bootstrap(),
      child: MaterialApp(
        title: 'Aether',
        debugShowCheckedModeBanner: false,
        theme: buildAetherTheme(),
        home: const AetherGate(),
      ),
    );
  }
}

class AetherGate extends StatelessWidget {
  const AetherGate({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<AetherController>().phase;

    switch (phase) {
      case AuthPhase.loading:
        return Scaffold(
          body: Container(
            decoration: aetherBackdrop(),
            child: const Center(
              child: CircularProgressIndicator(color: AetherColors.mint),
            ),
          ),
        );
      case AuthPhase.signedIn:
        return const ChatScreen();
      case AuthPhase.signedOut:
      case AuthPhase.awaitingApproval:
      case AuthPhase.error:
        return const LoginScreen();
    }
  }
}
