// test/support/fakes/fake_active_editor.dart
//
// Fake compartilhada de [ActivePlaylistEditor] (E10) — reúne os
// comportamentos que 8 arquivos de teste reimplementavam: `build()` com
// estado inicial (nulo por padrão, como a implementação real), rastreio de
// `removeByKey`/`reorderFace`/`deleteActiveDraft`/`replaceByKey` e resultado
// configurável de `addToActive`.
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';

class FakeActiveEditor extends ActivePlaylistEditor {
  FakeActiveEditor([this.initial]);

  final List<PlaylistEntry>? initial;

  /// Resultado devolvido por [addToActive].
  var addToActiveResult = AddToActiveOutcome.added;

  /// Resultado devolvido por [replaceByKey].
  var replaceByKeyResult = true;

  /// Quando `true`, [addToActive] também empilha a entrada em `state` — só
  /// alguns testes precisam que `activeEntriesProvider` reflita o item
  /// recém-adicionado (ex.: para expor a chave a um `replaceByKey` seguinte).
  /// Mutável — arme com `..applyAddToActiveToState = true` depois de criar.
  var applyAddToActiveToState = false;

  final removedKeys = <String>[];
  final added = <({String id, MaterialKind? kind})>[];
  final replaced = <({String key, PlaylistEntry replacement})>[];
  List<String>? lastReorder;
  PlaylistMediaFace? lastReorderFace;
  var cleared = false;

  @override
  List<PlaylistEntry>? build() => initial;

  List<ActiveEntry> get _entries => activeEntriesOf(state ?? const []);

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    added.add((id: materialId, kind: kind));
    if (applyAddToActiveToState) {
      state = [
        ...?state,
        PlaylistEntry(id: materialId, kind: kind ?? MaterialKind.pdf),
      ];
    }
    return addToActiveResult;
  }

  @override
  Future<bool> replaceByKey(String key, PlaylistEntry replacement) async {
    replaced.add((key: key, replacement: replacement));
    return replaceByKeyResult;
  }

  @override
  Future<void> removeByKey(String key) async {
    removedKeys.add(key);
    state = [
      for (final active in _entries)
        if (active.key != key) active.entry,
    ];
  }

  @override
  Future<void> reorderFace(
    PlaylistMediaFace face,
    List<String> orderedKeys,
  ) async {
    lastReorderFace = face;
    lastReorder = orderedKeys;
    final byKey = {for (final active in _entries) active.key: active.entry};
    state = [for (final key in orderedKeys) ?byKey[key]];
  }

  @override
  Future<void> deleteActiveDraft() async {
    cleared = true;
    state = const [];
  }
}
