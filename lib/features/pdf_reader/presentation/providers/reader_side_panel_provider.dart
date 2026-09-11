import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/providers/shared_prefs_provider.dart';

/// Painel lateral do leitor (PDF/cifra) aberto/fechado — spec A.6 C7.
///
/// Só tem efeito visual em tela larga ([isWideLayout]) e fora de fullscreen —
/// ver [ReaderSplitLayout]. Persiste em [SharedPreferences]
/// ([StorageKeys.readerSidePanelOpen]); default `true` (painel aberto).
final readerSidePanelOpenProvider =
    NotifierProvider<ReaderSidePanelOpenNotifier, bool>(
      ReaderSidePanelOpenNotifier.new,
    );

/// Alterna e persiste a visibilidade do painel lateral do leitor.
class ReaderSidePanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(StorageKeys.readerSidePanelOpen) ?? true;
  }

  /// Alterna aberto/fechado e persiste a escolha.
  void toggle() {
    final next = !state;
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _persist(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.readerSidePanelOpen, value);
  }
}
