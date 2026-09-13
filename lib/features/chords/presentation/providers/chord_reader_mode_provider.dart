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

/// Transposição em semitons da cifra aberta, por `chordId` (C10).
///
/// **Não** é persistida entre sessões: fechar o app volta ao tom original.
/// Mas dentro da mesma sessão cada louvor guarda seu próprio tom — a família
/// é quem garante isso: abrir outro louvor não herda a transposição do
/// anterior (cada `chordId` novo começa do zero em [build]), e voltar ao
/// mesmo louvor mantém o tom escolhido, porque o estado daquele `chordId`
/// continua vivo (não é `autoDispose`) enquanto o app roda.
class ChordReaderTransposeNotifier extends Notifier<int> {
  ChordReaderTransposeNotifier(this.chordId);

  /// Chave da cifra dona deste estado — mesma usada por [chordSongProvider].
  final String chordId;

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
    NotifierProvider.family<ChordReaderTransposeNotifier, int, String>(
      ChordReaderTransposeNotifier.new,
    );
