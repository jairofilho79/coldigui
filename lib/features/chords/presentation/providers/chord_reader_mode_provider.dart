import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/chord_reader_preferences_datasource.dart';
import '../theme/chord_reader_theme.dart';

/// Claro/escuro do leitor de cifras, persistido entre sessões.
///
/// [sharedPreferencesProvider] é síncrono e lança se não houver override — o
/// `main()` do app já faz esse override antes do `runApp`. Testes de widget que
/// tocam neste provider precisam de `SharedPreferences.setMockInitialValues`
/// **e** do override no `ProviderScope`.
class ChordReaderModeNotifier extends Notifier<ChordReaderMode> {
  @override
  ChordReaderMode build() => _datasource.getMode();

  ChordReaderPreferencesDatasource get _datasource =>
      ChordReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() {
    final next = state.toggle();
    state = next;
    unawaited(_datasource.saveMode(next));
  }
}

final chordReaderModeProvider =
    NotifierProvider<ChordReaderModeNotifier, ChordReaderMode>(
      ChordReaderModeNotifier.new,
    );
