import 'package:aether/main.dart';
import 'package:aether/services/settings_store.dart';
import 'package:aether/widgets/broken_heart_logo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Aether shows broken heart brand and Imagine entry', (tester) async {
    await tester.pumpWidget(AetherApp(store: SettingsStore()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AETHER'), findsOneWidget);
    expect(find.byType(BrokenHeartLogo), findsWidgets);
    expect(find.byTooltip('Imagine studio'), findsOneWidget);
  });
}
