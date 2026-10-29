import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../playlists/domain/entities/active_entry.dart';
import '../../../playlists/presentation/providers/playlist_session_prefs.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_items_provider.dart';

/// Chave da entrada focada na lista ativa — `null` = «a primeira».
///
/// Vive **separada** do índice de propósito: quem foca (o
/// `ActivePlaylistEditor`, o `PlaylistsNotifier`) está a montante da lista
/// derivada, e um provider que dependesse de [carouselItemsProvider] fecharia
/// um ciclo. Este aqui só depende de SharedPreferences.
///
/// Persistida na mesma pref de sempre (`carousel_focused_pdf_id`): os valores
/// gravados por builds anteriores são ids, e um id é a chave da primeira
/// ocorrência ([entryKeyFor]).
class CarouselFocusedKeyNotifier extends Notifier<String?> {
  @override
  String? build() {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(kCarouselFocusedPdfIdPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Foca a entrada de chave [key].
  void focus(String key) {
    if (state == key) return;
    state = key;
    unawaited(_persist(key));
  }

  /// Volta ao começo da lista — o índice resolve para 0.
  void clear() {
    if (state == null) return;
    state = null;
    unawaited(_persist(null));
  }

  Future<void> _persist(String? key) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (key == null || key.isEmpty) {
      await prefs.remove(kCarouselFocusedPdfIdPrefsKey);
    } else {
      await prefs.setString(kCarouselFocusedPdfIdPrefsKey, key);
    }
  }
}

/// Chave focada na lista ativa — ver [CarouselFocusedKeyNotifier].
final carouselFocusedKeyProvider =
    NotifierProvider<CarouselFocusedKeyNotifier, String?>(
      CarouselFocusedKeyNotifier.new,
    );

/// Índice do item visível na barra do carousel (lista ativa inteira).
///
/// Resolve [carouselFocusedKeyProvider] contra [carouselItemsProvider]:
/// chave nula → primeiro item; chave que não existe mais → o índice anterior,
/// preso ao intervalo válido (o vizinho de quem saiu).
class CarouselFocusedIndexNotifier extends Notifier<int> {
  int _currentIndex = 0;

  @override
  int build() {
    return _resolve(
      ref.watch(carouselItemsProvider),
      ref.watch(carouselFocusedKeyProvider),
    );
  }

  int _resolve(List<CarouselItem> items, String? focusedKey) {
    if (items.isEmpty || focusedKey == null) {
      _currentIndex = 0;
      return 0;
    }

    final index = items.indexWhere((item) => item.key == focusedKey);
    if (index >= 0) {
      _currentIndex = index;
      return index;
    }

    final clamped = _currentIndex.clamp(0, items.length - 1);
    _currentIndex = clamped;
    return clamped;
  }

  void goPrevious() {
    final items = ref.read(carouselItemsProvider);
    if (items.isEmpty || _currentIndex <= 0) return;
    ref
        .read(carouselFocusedKeyProvider.notifier)
        .focus(items[_currentIndex - 1].key);
  }

  void goNext() {
    final items = ref.read(carouselItemsProvider);
    if (items.isEmpty || _currentIndex >= items.length - 1) return;
    ref
        .read(carouselFocusedKeyProvider.notifier)
        .focus(items[_currentIndex + 1].key);
  }

  /// Foca a ocorrência de chave [key], se ela existir na lista.
  void focusKey(String key) {
    final items = ref.read(carouselItemsProvider);
    if (!items.any((item) => item.key == key)) return;
    ref.read(carouselFocusedKeyProvider.notifier).focus(key);
  }

  /// Volta ao primeiro item — usado ao trocar de lista ativa.
  void reset() => ref.read(carouselFocusedKeyProvider.notifier).clear();

  /// Esquece a entrada focada — usado ao limpar a seleção.
  void clearFocus() => ref.read(carouselFocusedKeyProvider.notifier).clear();
}

/// Índice 0-based do louvor exibido na [CarouselNavigatorBar] do shell.
final carouselFocusedIndexProvider =
    NotifierProvider<CarouselFocusedIndexNotifier, int>(
      CarouselFocusedIndexNotifier.new,
    );
