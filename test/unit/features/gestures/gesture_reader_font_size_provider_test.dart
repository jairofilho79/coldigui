import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart';
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
  test('começa em 18 sem valor salvo', () async {
    final (c, _) = await _setup();
    expect(c.read(gestureReaderFontSizeProvider), 18);
  });

  test('lê o valor salvo, grampeado na faixa', () async {
    final (c, _) = await _setup(initial: {StorageKeys.gestureReaderFontSize: 99.0});
    expect(c.read(gestureReaderFontSizeProvider), 28);
  });

  test('increase/decrease persistem', () async {
    final (c, prefs) = await _setup();
    c.read(gestureReaderFontSizeProvider.notifier).increase();
    expect(c.read(gestureReaderFontSizeProvider), 20);
    expect(prefs.getDouble(StorageKeys.gestureReaderFontSize), 20);
    c.read(gestureReaderFontSizeProvider.notifier).decrease();
    c.read(gestureReaderFontSizeProvider.notifier).decrease();
    expect(c.read(gestureReaderFontSizeProvider), 16);
  });
}
