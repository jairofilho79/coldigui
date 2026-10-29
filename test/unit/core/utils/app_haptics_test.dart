import 'package:coldigui/core/utils/app_haptics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppHaptics', () {
    tearDown(() {
      AppHaptics.enabled = true;
    });

    test('métodos de feedback tátil executam sem lançar exceções', () async {
      AppHaptics.enabled = true;

      await expectLater(AppHaptics.selectionClick(), completes);
      await expectLater(AppHaptics.lightImpact(), completes);
      await expectLater(AppHaptics.mediumImpact(), completes);
    });

    test('quando enabled é falso, métodos retornam imediatamente sem invocar canal', () async {
      AppHaptics.enabled = false;

      await expectLater(AppHaptics.selectionClick(), completes);
      await expectLater(AppHaptics.lightImpact(), completes);
      await expectLater(AppHaptics.mediumImpact(), completes);
    });
  });
}
