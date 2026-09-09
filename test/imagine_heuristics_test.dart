import 'package:aether/state/aether_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image prompt heuristics', () {
    final ctrl = AetherController();
    expect(ctrl.looksLikeImageRequest('/imagine a nebula'), isTrue);
    expect(ctrl.looksLikeImageRequest('draw a cat'), isTrue);
    expect(ctrl.looksLikeImageRequest('hello there'), isFalse);
    expect(ctrl.imagePromptFrom('/imagine a nebula'), 'a nebula');
    expect(ctrl.imagePromptFrom('draw a cat'), 'a cat');
  });
}
