import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_linear_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_mode_provider.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
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
  group('datasource', () {
    test('defaults: claro, linear ligado, velocidade 3', () async {
      final (_, prefs) = await _setup();
      final ds = GestureReaderPreferencesDatasource(prefs);
      expect(ds.getMode(), GestureReaderMode.light);
      expect(ds.getLinear(), isTrue);
      expect(ds.getAutoscrollSpeed(), 3);
    });

    test('valores inválidos caem no default ou são grampeados', () async {
      final (_, prefs) = await _setup(initial: {
        StorageKeys.gestureReaderMode: 'sepia',
        StorageKeys.gestureAutoscrollSpeed: 42,
      });
      final ds = GestureReaderPreferencesDatasource(prefs);
      expect(ds.getMode(), GestureReaderMode.light);
      expect(ds.getAutoscrollSpeed(), 5);
    });

    test('save/get ida e volta', () async {
      final (_, prefs) = await _setup();
      final ds = GestureReaderPreferencesDatasource(prefs);
      await ds.saveMode(GestureReaderMode.dark);
      await ds.saveLinear(false);
      await ds.saveAutoscrollSpeed(1);
      expect(ds.getMode(), GestureReaderMode.dark);
      expect(ds.getLinear(), isFalse);
      expect(ds.getAutoscrollSpeed(), 1);
      expect(prefs.getString(StorageKeys.gestureReaderMode), 'dark');
      expect(prefs.getBool(StorageKeys.gestureReaderLinear), isFalse);
      expect(prefs.getInt(StorageKeys.gestureAutoscrollSpeed), 1);
    });
  });

  group('gestureReaderModeProvider', () {
    test('começa claro; toggle vai a escuro e persiste', () async {
      final (c, prefs) = await _setup();
      expect(c.read(gestureReaderModeProvider), GestureReaderMode.light);
      c.read(gestureReaderModeProvider.notifier).toggle();
      expect(c.read(gestureReaderModeProvider), GestureReaderMode.dark);
      expect(prefs.getString(StorageKeys.gestureReaderMode), 'dark');
    });

    test('lê o salvo', () async {
      final (c, _) = await _setup(initial: {StorageKeys.gestureReaderMode: 'dark'});
      expect(c.read(gestureReaderModeProvider), GestureReaderMode.dark);
    });
  });

  group('gestureReaderLinearProvider', () {
    test('começa ligado; toggle desliga e persiste', () async {
      final (c, prefs) = await _setup();
      expect(c.read(gestureReaderLinearProvider), isTrue);
      c.read(gestureReaderLinearProvider.notifier).toggle();
      expect(c.read(gestureReaderLinearProvider), isFalse);
      expect(prefs.getBool(StorageKeys.gestureReaderLinear), isFalse);
    });

    test('lê o salvo', () async {
      final (c, _) = await _setup(initial: {StorageKeys.gestureReaderLinear: false});
      expect(c.read(gestureReaderLinearProvider), isFalse);
    });
  });
}
