import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';
import '../../domain/entities/gesture_reader_font_size.dart';

/// Corpo da letra no leitor de gestos, persistido entre sessões.
///
/// Mesmo padrão de `ChordReaderFontSizeNotifier`: `sharedPreferencesProvider`
/// é síncrono e o `main()` já o sobrescreve; testes de widget precisam de
/// `SharedPreferences.setMockInitialValues` **e** do override no `ProviderScope`.
class GestureReaderFontSizeNotifier extends Notifier<double> {
  @override
  double build() => _datasource.getFontSize();

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void increase() => _set(GestureReaderFontSize.increase(state));

  void decrease() => _set(GestureReaderFontSize.decrease(state));

  void _set(double next) {
    if (next == state) return;
    state = next;
    unawaited(_datasource.saveFontSize(next));
  }
}

final gestureReaderFontSizeProvider =
    NotifierProvider<GestureReaderFontSizeNotifier, double>(
      GestureReaderFontSizeNotifier.new,
    );
