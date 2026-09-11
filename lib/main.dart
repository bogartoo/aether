import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/chat_screen.dart';
import 'screens/connect_screen.dart';
import 'state/hrtbrkr_controller.dart';
import 'theme/hrtbrkr_logo.dart';
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HrtbrkrLogo(size: 72, iconSize: 34),
                  const SizedBox(height: 28),
                  Text(
                    'HRTBRKR',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: HrtbrkrColors.pink,
                    ),
                  ),
                ],
              ),
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
