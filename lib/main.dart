import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings_store.dart';
import 'theme/aether_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AetherApp(store: SettingsStore()));
}

class AetherApp extends StatelessWidget {
  const AetherApp({super.key, required this.store});

  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether',
      debugShowCheckedModeBanner: false,
      theme: buildAetherTheme(),
      home: HomeScreen(store: store),
    );
  }
}
