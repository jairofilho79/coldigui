import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';

/// Leitura linear (`true`, default) ou estruturada (`false`), persistida.
///
/// Linear = `linearizeGestureDocument` antes da página, do `flatten` e do
/// foco; estruturada = o documento como veio, com chaves e instruções.
class GestureReaderLinearNotifier extends Notifier<bool> {
  @override
  bool build() => _datasource.getLinear();

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() {
    final next = !state;
    state = next;
    unawaited(_datasource.saveLinear(next));
  }
}

final gestureReaderLinearProvider =
    NotifierProvider<GestureReaderLinearNotifier, bool>(
      GestureReaderLinearNotifier.new,
    );
