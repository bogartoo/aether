import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/chat_screen.dart';
import 'screens/connect_screen.dart';
import 'state/hrtbrkr_controller.dart';
import 'theme/hrtbrkr_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HrtbrkrRoot());
}

class HrtbrkrRoot extends StatelessWidget {
  const HrtbrkrRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HrtbrkrController()..bootstrap(),
      child: MaterialApp(
        title: 'HRTBRKR',
        debugShowCheckedModeBanner: false,
        theme: buildHrtbrkrTheme(),
        home: const HrtbrkrGate(),
      ),
    );
  }
}

class HrtbrkrGate extends StatelessWidget {
  const HrtbrkrGate({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<HrtbrkrController>().phase;

    switch (phase) {
      case ConnPhase.loading:
      case ConnPhase.connecting:
        return Scaffold(
          body: Container(
            decoration: hrtbrkrBackdrop(),
            child: const Center(
              child: CircularProgressIndicator(color: HrtbrkrColors.mint),
            ),
          ),
        );
      case ConnPhase.connected:
        return const ChatScreen();
      case ConnPhase.disconnected:
      case ConnPhase.error:
        return const ConnectScreen();
    }
  }
}
