import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrtbrkr/screens/connect_screen.dart';
import 'package:hrtbrkr/state/hrtbrkr_controller.dart';
import 'package:hrtbrkr/theme/hrtbrkr_theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('connect screen shows HRTBRKR brand', (tester) async {
    final ctrl = HrtbrkrController();
    ctrl.phase = ConnPhase.disconnected;

    await tester.pumpWidget(
      ChangeNotifierProvider<HrtbrkrController>.value(
        value: ctrl,
        child: MaterialApp(
          theme: buildHrtbrkrTheme(),
          home: const ConnectScreen(),
        ),
      ),
    );

    expect(find.text('HRTBRKR'), findsOneWidget);
    expect(find.text('Connect local LLM'), findsOneWidget);
    expect(find.textContaining('local'), findsWidgets);
  });
}
