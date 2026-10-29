import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';
import '../theme/gesture_reader_theme.dart';

/// Claro/escuro do leitor de gestos, persistido entre sessões.
///
/// Mesmo padrão de `GestureReaderFontSizeNotifier`: `sharedPreferencesProvider`
/// é síncrono e o `main()` já o sobrescreve; testes de widget precisam de
/// `SharedPreferences.setMockInitialValues` **e** do override no `ProviderScope`.
class GestureReaderModeNotifier extends Notifier<GestureReaderMode> {
  @override
  GestureReaderMode build() => _datasource.getMode();

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() {
    final next = state.toggle();
    state = next;
    unawaited(_datasource.saveMode(next));
  }
}

final gestureReaderModeProvider =
    NotifierProvider<GestureReaderModeNotifier, GestureReaderMode>(
      GestureReaderModeNotifier.new,
    );
