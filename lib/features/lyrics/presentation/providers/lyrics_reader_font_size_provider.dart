import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/lyrics_reader_preferences_datasource.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';

/// Corpo do texto no leitor de letra, persistido entre sessões.
///
/// Mesmo padrão de `GestureReaderFontSizeNotifier`: `sharedPreferencesProvider`
/// é síncrono e o `main()` já o sobrescreve.
class LyricsReaderFontSizeNotifier extends Notifier<double> {
  @override
  double build() => _datasource.getFontSize();

  LyricsReaderPreferencesDatasource get _datasource =>
      LyricsReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void increase() => _set(LyricsReaderFontSize.increase(state));

  void decrease() => _set(LyricsReaderFontSize.decrease(state));

  void _set(double next) {
    if (next == state) return;
    state = next;
    unawaited(_datasource.saveFontSize(next));
  }
}

final lyricsReaderFontSizeProvider =
    NotifierProvider<LyricsReaderFontSizeNotifier, double>(
      LyricsReaderFontSizeNotifier.new,
    );
