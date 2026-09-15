import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../live/domain/live_coldigom_only.dart';
import '../../../live/domain/live_material_projection.dart';
import '../../../live/presentation/providers/live_material_choice_provider.dart';
import '../../../live/presentation/providers/live_projection_provider.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/active_entry.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/usecases/update_playlist.dart';
import 'active_playlist_provider.dart';
import 'playlist_sync_provider.dart';
import 'playlists_provider.dart';

export '../../domain/entities/active_entry.dart';

/// Debounce entre reordenações consecutivas antes de persistir a lista ativa.
const activeReorderPersistDebounce = Duration(milliseconds: 100);

final _log = AppLogger.of('playlists');

/// Resultado de [ActivePlaylistEditor.addToActive].
enum AddToActiveOutcome {
  /// A entrada entrou na lista ativa.
  added,

  /// O id já estava na lista e `allowDuplicate` era `false`.
  alreadyPresent,

  /// Isar indisponível (modo degradado): nada foi gravado.
  storageUnavailable,

  /// A lista ativa é a projeção de uma sessão ao vivo: o consumidor não
  /// edita (spec lista-ao-vivo D4). Nada foi gravado.
  following,

  /// O gestor está transmitindo e o material não é do Coldigom
  /// (`isColdigomEntry`): a lista ao vivo só leva material Coldigom. Nada
  /// foi gravado.
  liveColdigomOnly,
}

/// Todas as mutações da seleção (D3).
///
/// A lista ativa é a única fonte de verdade: cada mutação grava
/// `SavedPlaylist.entries` por [UpdatePlaylist], recarrega
/// [playlistsProvider] e, se a lista for salva, dispara o sync na nuvem.
///
/// O `state` é o **override otimista** da reordenação em voo (`null` quando
/// não há nenhuma): [reorder] aplica a nova ordem na hora, agenda a
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

  /// `true` enquanto a lista ativa é a projeção de um gestor ao vivo — toda
  /// mutação daqui é ignorada (a UI também as desativa).
  bool get isFollowingLive => ref.read(liveProjectionProvider) != null;

  /// `true` enquanto este app transmite a lista ativa como gestor — entra
  /// só material Coldigom (`live_coldigom_only.dart`). Lê o espelho
  /// [liveLeadingProvider]: o controller da sessão observa este editor, e
  /// ler o controller daqui fecharia um ciclo.
  bool get isLeadingLive => ref.read(liveLeadingProvider);

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
    if (isFollowingLive) return AddToActiveOutcome.following;
    if (isLeadingLive &&
        !isColdigomEntry(
          PlaylistEntry(
            id: materialId,
            kind: kind ?? materialIdKindOf(materialId),
          ),
        )) {
      return AddToActiveOutcome.liveColdigomOnly;
    }
    // O app monta durante a abertura do Isar (A8): um toque nos primeiros
    // segundos do boot frio espera o banco decidir em vez de responder
    // «armazenamento indisponível» para um banco que só está abrindo.
    await awaitIsarSettled(ref);
    if (!ref.mounted) return AddToActiveOutcome.storageUnavailable;
    try {
      return await _addToActive(
        materialId,
        kind: kind,
        allowDuplicate: allowDuplicate,
      );
    } on StorageUnavailableException catch (e) {
      _log.warn('sem storage ao adicionar à lista ativa', e);
      return AddToActiveOutcome.storageUnavailable;
    }
  }

  Future<AddToActiveOutcome> _addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    // A reordenação em voo vai a disco **antes**: só assim `active.entries`,
    // lido do repositório logo abaixo, já está na ordem que o usuário vê.
    await _settlePendingReorder();

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
      _focusAfterAdd(entry);
      return AddToActiveOutcome.added;
    }

    final occurrencesBefore = active.entries
        .where((e) => e.id == materialId)
        .length;
    if (!allowDuplicate && occurrencesBefore > 0) {
      _focusAfterAdd(entry);
      return AddToActiveOutcome.alreadyPresent;
    }

    await _persistEntries(active.playlistId, [...active.entries, entry]);
    _focusAfterAdd(entry, occurrence: occurrencesBefore);
    return AddToActiveOutcome.added;
  }

  /// Acrescenta [entries] ao fim da lista ativa **como vieram** — sem dedupe.
  ///
  /// É o caminho do import de share/social: a origem pode repetir um louvor, e
  /// a reunião importada tem que repetir também. Devolve quantas entraram.
  Future<int> addEntriesToActive(List<PlaylistEntry> entries) async {
    if (isFollowingLive) return 0;
    if (entries.isEmpty) return 0;
    await awaitIsarSettled(ref);
    if (!ref.mounted) return 0;
    try {
      await _settlePendingReorder();
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
      _log.warn('sem storage ao importar entradas', e);
      return 0;
    }
  }

  /// Remove a ocorrência de chave [key] — as outras do mesmo id ficam.
  Future<void> removeByKey(String key) async {
    if (isFollowingLive) return;
    await _settlePendingReorder();
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;
    final entries = _entries;
    final index = _indexOfKey(entries, key);
    if (index < 0) return;

    final next = [...entries]..removeAt(index);
    // Override até o reload: a barra mostra a lista já sem a entrada, em vez
    // de piscar o conteúdo antigo enquanto a escrita acontece. `finally`: uma
    // escrita que falha (lista já apagada, storage fora) não pode deixar o
    // override preso mostrando uma remoção que não aconteceu.
    state = next;
    try {
      await _persistEntries(activeId, next);
    } finally {
      if (ref.mounted) state = null;
    }
  }

  /// Remove **todas** as ocorrências de [materialId] da lista ativa.
  ///
  /// É o `×` do sheet de materiais: ele só sabe que o material «está na
  /// lista» (por id, não por chave), então tirar dali significa que o ✓ some
  /// — inclusive quando o material foi repetido. Lança
  /// [StorageUnavailableException] como [removeByKey].
  Future<void> removeById(String materialId) async {
    if (isFollowingLive) return;
    await _settlePendingReorder();
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;
    final entries = _entries;
    final next = [
      for (final entry in entries)
        if (entry.id != materialId) entry,
    ];
    if (next.length == entries.length) return;

    // Mesmo override otimista de removeByKey.
    state = next;
    try {
      await _persistEntries(activeId, next);
    } finally {
      if (ref.mounted) state = null;
    }
  }

  /// Troca a entrada de chave [key] por [replacement], na mesma posição.
  ///
  /// Devolve `false` se a chave não existe na lista ativa.
  Future<bool> replaceByKey(String key, PlaylistEntry replacement) async {
    if (isFollowingLive) {
      // Seguindo: a troca é o material **próprio** do consumidor para a
      // chave do gestor (`projectLiveEntries`) — só na sessão, nada no Isar.
      if (!ref.read(activeEntriesProvider).any((e) => e.key == key)) {
        return false;
      }
      ref.read(liveMaterialOverridesProvider.notifier).set(key, replacement);
      return true;
    }
    if (isLeadingLive && !isColdigomEntry(replacement)) return false;
    await _settlePendingReorder();
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return false;
    final entries = _entries;
    final index = _indexOfKey(entries, key);
    if (index < 0) return false;

    final next = [...entries];
    next[index] = replacement;
    state = next;
    try {
      await _persistEntries(activeId, next);
    } finally {
      if (ref.mounted) state = null;
    }
    return true;
  }

  /// Reordena a lista ativa inteira.
  ///
  /// [orderedKeys] são as chaves de [ActiveEntry] na ordem desejada. Aplica o
  /// override otimista na hora e persiste depois de
  /// [activeReorderPersistDebounce] (a última ordem vence).
  ///
  /// [orderedKeys] tem que ser uma **permutação** das chaves da lista:
  /// reordenar é permutar, não editar. Uma lista curta, com chave desconhecida
  /// ou repetida não apaga entrada nenhuma — a reordenação é ignorada e
  /// registrada.
  Future<void> reorder(List<String> orderedKeys) async {
    if (isFollowingLive) return;
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return;
    final entries = _entries;

    final byKey = <String, PlaylistEntry>{
      for (final active in activeEntriesOf(entries)) active.key: active.entry,
    };

    final seen = <String>{};
    final reordered = <PlaylistEntry>[];
    for (final key in orderedKeys) {
      final entry = byKey[key];
      if (entry == null) continue;
      if (!seen.add(key)) continue;
      reordered.add(entry);
    }

    if (reordered.length != byKey.length) {
      _log.warn(
        'reorder ignorado: ${orderedKeys.length} chaves resolveram '
        '${reordered.length} de ${byKey.length} entradas',
      );
      return;
    }

    state = reordered;

    _pendingReorder = state;
    _pendingPlaylistId = activeId;
    _pendingUpdate = ref.read(updatePlaylistProvider);
    _reorderPersistTimer?.cancel();
    _reorderPersistTimer = Timer(activeReorderPersistDebounce, () {
      unawaited(_flushPendingReorder());
    });
  }

  /// Persiste **agora** a reordenação que estiver esperando o debounce.
  ///
  /// Toda mutação começa por aqui: o `_pendingReorder` guardado é a ordem
  /// **anterior** à mutação, e deixá-lo armado faria o flush sobrescrever o que
  /// a mutação acabou de gravar (a entrada removida voltaria, a adicionada
  /// sumiria). Levar a ordem a disco antes também é o que faz a leitura do
  /// repositório em [_addToActive] já vir na ordem que o usuário vê.
  Future<void> _settlePendingReorder() async {
    if (_pendingReorder == null) return;
    _reorderPersistTimer?.cancel();
    _reorderPersistTimer = null;
    await _flushPendingReorder();
  }

  /// Descarta a reordenação pendente sem gravar — a lista vai sumir de qualquer
  /// jeito.
  void _dropPendingReorder() {
    _reorderPersistTimer?.cancel();
    _reorderPersistTimer = null;
    _pendingReorder = null;
    _pendingPlaylistId = null;
  }

  /// Grava a reordenação pendente. Roda de um [Timer] (sem quem espere) ou de
  /// [_settlePendingReorder], então o erro de escrita é registrado aqui, não
  /// propagado: propagar de um Timer seria erro assíncrono sem dono, e a
  /// mutação que chamou o settle ainda vai gravar por cima.
  Future<void> _flushPendingReorder() async {
    final pending = _pendingReorder;
    final playlistId = _pendingPlaylistId;
    if (pending == null || playlistId == null) return;
    _pendingReorder = null;
    _pendingPlaylistId = null;

    try {
      await _persistEntries(playlistId, pending);
    } on Object catch (e, stackTrace) {
      _log.error('reordenação de $playlistId não foi gravada', e, stackTrace);
    } finally {
      // O override só sai depois do reload: assim a barra nunca pisca a ordem
      // antiga entre a escrita e o estado novo de `playlistsProvider`. E só
      // quando nenhuma reordenação mais nova chegou durante o `await` — senão
      // a barra piscaria a ordem recém-gravada até o próximo flush.
      if (ref.mounted && _pendingReorder == null) state = null;
    }
  }

  /// Desanexa a lista ativa — a lista continua existindo, só deixa de ser a
  /// seleção.
  Future<void> detachActive() async {
    // A lista continua existindo: a ordem que o usuário acabou de arrastar tem
    // que ir a disco antes de a seleção soltá-la.
    await _settlePendingReorder();
    state = null;
    ref.read(activePlaylistIdProvider.notifier).clear();
    await ref.read(playlistsProvider.notifier).reload();
  }

  /// Rascunho ativo: apaga e desanexa. Lista salva: só desanexa.
  Future<void> deleteActiveDraft() async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) {
      _dropPendingReorder();
      state = null;
      return;
    }

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    if (active != null && !active.salva) {
      _dropPendingReorder();
      await ref.read(deletePlaylistProvider)(playlistId: activeId);
    } else {
      // Salva: só desanexa, então a reordenação pendente ainda importa.
      await _settlePendingReorder();
    }
    state = null;
    ref.read(activePlaylistIdProvider.notifier).clear();
    await ref.read(playlistsProvider.notifier).reload();
  }

  /// Torna [playlistId] a lista ativa. Devolve o id ativo anterior (D6).
  Future<String?> activate(String playlistId) async {
    // A lista que era ativa continua existindo — grava a ordem pendente dela.
    await _settlePendingReorder();
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

  /// Foca a ocorrência [occurrence] (0-based) do material recém-adicionado —
  /// com `allowDuplicate`, a **nova**, não a primeira.
  ///
  /// Sem faces (spec 2026-09-12, D1): a lista ativa é uma só, com PDF, cifra,
  /// gesto e áudio juntos — um áudio recém-adicionado foca o próprio chip
  /// como qualquer outro tipo.
  void _focusAfterAdd(PlaylistEntry entry, {int occurrence = 0}) {
    ref
        .read(carouselFocusedKeyProvider.notifier)
        .focus(entryKeyFor(entry.id, occurrence));
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
///
/// Enquanto o app segue um gestor ao vivo ([liveProjectionProvider] não
/// nulo), a lista ativa **é** o snapshot dele — com as chaves do gestor e o
/// material do consumidor em cada posição ([projectLiveEntries]: escolha
/// manual > favoritos > material do gestor). Barra, leitor e player não
/// sabem a diferença; a lista local fica intocada e volta ao sair.
final activeEntriesProvider = Provider<List<ActiveEntry>>((ref) {
  final live = ref.watch(liveProjectionProvider);
  if (live != null) {
    return projectLiveEntries(
      live.entries,
      manual: ref.watch(liveMaterialOverridesProvider),
      auto: ref.watch(liveAutoMaterialResolverProvider),
    );
  }
  final override = ref.watch(activePlaylistEditorProvider);
  final entries =
      override ?? ref.watch(activePlaylistProvider)?.entries ?? const [];
  return activeEntriesOf(entries);
});
