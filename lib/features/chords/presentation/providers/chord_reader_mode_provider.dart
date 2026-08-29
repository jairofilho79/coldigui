import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/chord_reader_preferences_datasource.dart';
import '../../domain/entities/chord_reader_font_size.dart';
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

/// Corpo da letra no leitor, persistido entre sessões.
class ChordReaderFontSizeNotifier extends Notifier<double> {
  @override
  double build() => _datasource.getFontSize();

  ChordReaderPreferencesDatasource get _datasource =>
      ChordReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void increase() => _set(ChordReaderFontSize.increase(state));

  void decrease() => _set(ChordReaderFontSize.decrease(state));

  void _set(double next) {
    if (next == state) return;
    state = next;
    unawaited(_datasource.saveFontSize(next));
  }
}

final chordReaderFontSizeProvider =
    NotifierProvider<ChordReaderFontSizeNotifier, double>(
      ChordReaderFontSizeNotifier.new,
    );

/// Transposição em semitons da cifra aberta.
///
/// **Não** é persistida: cada abertura começa no tom original. Guardar por
/// cifra faria a mesma cifra abrir num tom que o usuário não escolheu naquela
/// sessão, e o botão de zerar não estaria à vista para explicar por quê.
class ChordReaderTransposeNotifier extends Notifier<int> {
  /// Além de seis semitons em qualquer direção é a mesma nota pelo outro nome.
  static const int limit = 6;

  @override
  int build() => 0;

  void up() => _set(state + 1);

  void down() => _set(state - 1);

  void reset() => _set(0);

  void _set(int next) {
    final clamped = next.clamp(-limit, limit);
    if (clamped == state) return;
    state = clamped;
  }
}

final chordReaderTransposeProvider =
    NotifierProvider<ChordReaderTransposeNotifier, int>(
      ChordReaderTransposeNotifier.new,
    );
