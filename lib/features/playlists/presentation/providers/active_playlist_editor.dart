import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/active_entry.dart';
import '../../domain/entities/playlist_media_face.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/usecases/update_playlist.dart';
import 'active_playlist_provider.dart';
import 'playlist_sync_provider.dart';
import 'playlists_provider.dart';

export '../../domain/entities/active_entry.dart';

/// Debounce entre reordenações consecutivas antes de persistir a lista ativa.
const activeReorderPersistDebounce = Duration(milliseconds: 100);

/// Resultado de [ActivePlaylistEditor.addToActive].
enum AddToActiveOutcome {
  /// A entrada entrou na lista ativa.
  added,

  /// O id já estava na lista e `allowDuplicate` era `false`.
  alreadyPresent,

  /// Isar indisponível (modo degradado): nada foi gravado.
  storageUnavailable,
}

/// Todas as mutações da seleção (D3).
///
/// A lista ativa é a única fonte de verdade: cada mutação grava
/// `SavedPlaylist.entries` por [UpdatePlaylist], recarrega
/// [playlistsProvider] e, se a lista for salva, dispara o sync na nuvem.
///
/// O `state` é o **override otimista** da reordenação em voo (`null` quando
/// não há nenhuma): [reorderFace] aplica a nova ordem na hora, agenda a
/// persistência em [activeReorderPersistDebounce] (a última ordem vence) e só
/// limpa o override depois do `reload` que segue a escrita.
class ActivePlaylistEditor extends Notifier<List<PlaylistEntry>?> {
  Timer? _reorderPersistTimer;
  List<PlaylistEntry>? _pendingReorder;
  String? _pendingPlaylistId;
  UpdatePlaylist? _pendingUpdate;

  @override
  List<PlaylistEntry>? build() {
    ref.onDispose(() {
      _reorderPersistTimer?.cancel();
      final pending = _pendingReorder;
      final playlistId = _pendingPlaylistId;
      final update = _pendingUpdate;
      _pendingReorder = null;
      if (pending == null || playlistId == null || update == null) return;
      // O container está indo embora: persiste com o use case já capturado, sem
      // tocar em `ref` (nem reload, nem sync — não há mais quem escute).
      unawaited(update(playlistId: playlistId, entries: pending));
    });
    return null;
  }

  /// Entradas correntes: o override otimista, ou o que a lista ativa tem.
  List<PlaylistEntry> get _entries =>
      state ?? ref.read(activePlaylistProvider)?.entries ?? const [];

  /// Adiciona [materialId] à lista ativa, criando um rascunho se não houver.
  ///
  /// Sem storage devolve [AddToActiveOutcome.storageUnavailable] em vez de
  /// propagar: os chamadores disparam isto de futuros não aguardados, onde a
  /// exceção viraria erro assíncrono sem nada visível ao usuário.
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    try {
      return await _addToActive(
        materialId,
        kind: kind,
        allowDuplicate: allowDuplicate,
      );
    } on StorageUnavailableException catch (e) {
      debugPrint('[playlists] sem storage ao adicionar à lista ativa: $e');
      return AddToActiveOutcome.storageUnavailable;
    }
  }

  Future<AddToActiveOutcome> _addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    final entry = PlaylistEntry(
      id: materialId,
      kind: kind ?? materialIdKindOf(materialId),
    );
    final activeId = ref.read(activePlaylistIdProvider);
    final active = activeId == null
        ? null
        : await ref.read(playlistRepositoryProvider).getById(activeId);

    if (active == null) {
      final result = await ref.read(ensureActivePlaylistProvider)(entry: entry);
      ref.read(activePlaylistIdProvider.notifier).set(result.playlistId);
      state = null;
      await ref.read(playlistsProvider.notifier).reload();
      _focusFirstOccurrence(materialId);
      return AddToActiveOutcome.added;
    }

    if (!allowDuplicate && active.entries.any((e) => e.id == materialId)) {
      _focusFirstOccurrence(materialId);
      return AddToActiveOutcome.alreadyPresent;
    }

    await _persistEntries(active.playlistId, [...active.entries, entry]);
    _focusFirstOccurrence(materialId);
    return AddToActiveOutcome.added;
  }

  /// Acrescenta [entries] ao fim da lista ativa **como vieram** — sem dedupe.
  ///
  /// É o caminho do import de share/social: a origem pode repetir um louvor, e
  /// a reunião importada tem que repetir também. Devolve quantas entraram.
  Future<int> addEntriesToActive(List<PlaylistEntry> entries) async {
    if (entries.isEmpty) return 0;
    try {
      final activeId = ref.read(activePlaylistIdProvider);
      final repository = ref.read(playlistRepositoryProvider);
      final active = activeId == null
          ? null
          : await repository.getById(activeId);

      if (active == null) {
        final result = await ref.read(ensureActivePlaylistProvider)(
          entry: entries.first,
        );
        ref.read(activePlaylistIdProvider.notifier).set(result.playlistId);
        state = null;
        if (entries.length > 1) {
          final created = await repository.getById(result.playlistId);
          await _persistEntries(result.playlistId, [
            ...?created?.entries,
            ...entries.skip(1),
          ]);
        } else {
          await ref.read(playlistsProvider.notifier).reload();
        }
        return entries.length;
      }

      await _persistEntries(active.playlistId, [...active.entries, ...entries]);
      return entries.length;
    } on StorageUnavailableException catch (e) {
      debugPrint('[playlists] sem storage ao importar entradas: $e');
      return 0;
    }
  }

  /// Remove a ocorrência de chave [key] — as outras do mesmo id ficam.
  Future<void> removeByKey(String key) async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;
    final entries = _entries;
    final index = _indexOfKey(entries, key);
    if (index < 0) return;

    final next = [...entries]..removeAt(index);
    state = null;
    await _persistEntries(activeId, next);
  }

  /// Troca a entrada de chave [key] por [replacement], na mesma posição.
  ///
  /// Devolve `false` se a chave não existe na lista ativa.
  Future<bool> replaceByKey(String key, PlaylistEntry replacement) async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return false;
    final entries = _entries;
    final index = _indexOfKey(entries, key);
    if (index < 0) return false;

    final next = [...entries];
    next[index] = replacement;
    state = null;
    await _persistEntries(activeId, next);
    return true;
  }

  /// Reordena **só** [face], preservando as posições da outra.
  ///
  /// [orderedKeys] são as chaves de [ActiveEntry] na ordem desejada. Aplica o
  /// override otimista na hora e persiste depois de
  /// [activeReorderPersistDebounce] (a última ordem vence).
  Future<void> reorderFace(
    PlaylistMediaFace face,
    List<String> orderedKeys,
  ) async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;
    final entries = _entries;
    final byKey = <String, PlaylistEntry>{
      for (final active in activeEntriesOf(entries)) active.key: active.entry,
    };
    final wantsAudio = face == PlaylistMediaFace.audio;
    final reordered = <PlaylistEntry>[
      for (final key in orderedKeys)
        if (byKey[key] != null && byKey[key]!.isAudio == wantsAudio)
          byKey[key]!,
    ];

    state = SavedPlaylist.replaceSubset(
      entries,
      reordered,
      (entry) => entry.isAudio == wantsAudio,
    );

    _pendingReorder = state;
    _pendingPlaylistId = activeId;
    _pendingUpdate = ref.read(updatePlaylistProvider);
    _reorderPersistTimer?.cancel();
    _reorderPersistTimer = Timer(activeReorderPersistDebounce, () {
      unawaited(_flushPendingReorder());
    });
  }

  Future<void> _flushPendingReorder() async {
    final pending = _pendingReorder;
    final playlistId = _pendingPlaylistId;
    if (pending == null || playlistId == null) return;
    _pendingReorder = null;
    _pendingPlaylistId = null;

    await _persistEntries(playlistId, pending);
    // O override só sai depois do reload: assim a barra nunca pisca a ordem
    // antiga entre a escrita e o estado novo de `playlistsProvider`.
    state = null;
  }

  /// Desanexa a lista ativa — a lista continua existindo, só deixa de ser a
  /// seleção.
  Future<void> detachActive() async {
    _reorderPersistTimer?.cancel();
    _pendingReorder = null;
    _pendingPlaylistId = null;
    state = null;
    ref.read(activePlaylistIdProvider.notifier).clear();
    await ref.read(playlistsProvider.notifier).reload();
  }

  /// Rascunho ativo: apaga e desanexa. Lista salva: só desanexa.
  Future<void> deleteActiveDraft() async {
    _reorderPersistTimer?.cancel();
    _pendingReorder = null;
    _pendingPlaylistId = null;
    state = null;

    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    if (active != null && !active.salva) {
      await ref.read(deletePlaylistProvider)(playlistId: activeId);
    }
    ref.read(activePlaylistIdProvider.notifier).clear();
    await ref.read(playlistsProvider.notifier).reload();
  }

  /// Torna [playlistId] a lista ativa. Devolve o id ativo anterior (D6).
  Future<String?> activate(String playlistId) async {
    _reorderPersistTimer?.cancel();
    _pendingReorder = null;
    _pendingPlaylistId = null;
    state = null;

    final previous = ref.read(activePlaylistIdProvider);
    ref.read(activePlaylistIdProvider.notifier).set(playlistId);
    await ref.read(playlistsProvider.notifier).reload();
    ref.read(carouselFocusedKeyProvider.notifier).clear();
    return previous;
  }

  /// Escreve [next] na lista, recarrega e sincroniza se a lista for salva.
  ///
  /// Um rascunho que fica sem entradas é apagado por [UpdatePlaylist]; quando
  /// isso acontece o id ativo é limpo, para não ficar apontando pra nada.
  Future<void> _persistEntries(
    String playlistId,
    List<PlaylistEntry> next,
  ) async {
    await ref.read(updatePlaylistProvider)(
      playlistId: playlistId,
      entries: next,
    );
    await ref.read(playlistsProvider.notifier).reload();

    var stillExists = false;
    var salva = false;
    for (final item in ref.read(playlistsProvider)) {
      if (item.playlist.playlistId != playlistId) continue;
      stillExists = true;
      salva = item.playlist.salva;
      break;
    }

    if (!stillExists) {
      if (ref.read(activePlaylistIdProvider) == playlistId) {
        ref.read(activePlaylistIdProvider.notifier).clear();
      }
      return;
    }
    if (salva) {
      unawaited(ref.read(playlistSyncProvider.notifier).sync());
    }
  }

  void _focusFirstOccurrence(String materialId) {
    ref
        .read(carouselFocusedKeyProvider.notifier)
        .focus(entryKeyFor(materialId, 0));
  }

  static int _indexOfKey(List<PlaylistEntry> entries, String key) {
    for (final active in activeEntriesOf(entries)) {
      if (active.key == key) return active.index;
    }
    return -1;
  }
}

/// Único ponto de mutação da seleção — ver [ActivePlaylistEditor].
final activePlaylistEditorProvider =
    NotifierProvider<ActivePlaylistEditor, List<PlaylistEntry>?>(
      ActivePlaylistEditor.new,
    );

/// Entradas da lista ativa com posição e chave, já com o override otimista.
final activeEntriesProvider = Provider<List<ActiveEntry>>((ref) {
  final override = ref.watch(activePlaylistEditorProvider);
  final entries =
      override ?? ref.watch(activePlaylistProvider)?.entries ?? const [];
  return activeEntriesOf(entries);
});
