import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_autoscroll_speed.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_autoscroll_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _setup({Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return (c, prefs);
}

void main() {
  test('faixa: 1–5, inicial 3, clamp', () {
    expect(GestureAutoscrollSpeed.min, 1);
    expect(GestureAutoscrollSpeed.max, 5);
    expect(GestureAutoscrollSpeed.initial, 3);
    expect(GestureAutoscrollSpeed.clamp(0), 1);
    expect(GestureAutoscrollSpeed.clamp(9), 5);
    expect(GestureAutoscrollSpeed.pxPerSecondPerLevel, 10);
  });

  test('começa parado na velocidade salva (ou 3)', () async {
    final (c, _) = await _setup(initial: {StorageKeys.gestureAutoscrollSpeed: 4});
    final state = c.read(gestureAutoscrollProvider);
    expect(state.running, isFalse);
    expect(state.speed, 4);
  });

  test('toggle liga e desliga; stop é idempotente', () async {
    final (c, _) = await _setup();
    final n = c.read(gestureAutoscrollProvider.notifier);
    // Mantém o autoDispose vivo durante o teste.
    final sub = c.listen(gestureAutoscrollProvider, (_, _) {});
    addTearDown(sub.close);
    n.toggle();
    expect(c.read(gestureAutoscrollProvider).running, isTrue);
    n.toggle();
    expect(c.read(gestureAutoscrollProvider).running, isFalse);
    n.stop();
    expect(c.read(gestureAutoscrollProvider).running, isFalse);
  });

  test('setSpeed grampeia e persiste; não toca em running', () async {
    final (c, prefs) = await _setup();
    final sub = c.listen(gestureAutoscrollProvider, (_, _) {});
    addTearDown(sub.close);
    final n = c.read(gestureAutoscrollProvider.notifier);
    n.toggle();
    n.setSpeed(9);
    expect(c.read(gestureAutoscrollProvider).speed, 5);
    expect(c.read(gestureAutoscrollProvider).running, isTrue);
    expect(prefs.getInt(StorageKeys.gestureAutoscrollSpeed), 5);
    n.setSpeed(-1);
    expect(c.read(gestureAutoscrollProvider).speed, 1);
  });

  test('running não persiste: novo container começa parado', () async {
    final (c, prefs) = await _setup();
    final sub = c.listen(gestureAutoscrollProvider, (_, _) {});
    c.read(gestureAutoscrollProvider.notifier).toggle();
    sub.close();
    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(gestureAutoscrollProvider).running, isFalse);
  });
}
