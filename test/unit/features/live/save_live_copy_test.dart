import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/domain/usecases/save_live_copy.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Só o que o use case toca: `create` grava, `getById` devolve.
class _MemoryRepository implements PlaylistRepository {
  final Map<String, SavedPlaylist> rows = {};
  var nextId = 0;

  @override
  Future<String> create({
    required String nome,
    List<PlaylistEntry>? entries,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
    String? ownerSub,
  }) async {
    final id = playlistId ?? 'id-${nextId++}';
    rows[id] = SavedPlaylist(
      playlistId: id,
      nome: nome,
      createdAt: createdAt ?? DateTime(2026),
      entries: entries ?? const [],
      salva: salva,
      savedAt: savedAt,
      syncStatus: syncStatus,
      ownerSub: ownerSub,
    );
    return id;
  }

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => rows[playlistId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('cria lista salva pendingPush com as entradas do snapshot, na ordem e com repetições', () async {
    final repo = _MemoryRepository();
    final snapshot = LiveSnapshot(
      playlistId: 'remota',
      name: 'Culto',
      entries: const [
        PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 't', kind: MaterialKind.audio),
      ],
      focusKey: null,
    );
    final saved = await SaveLiveCopy(repo)
        .call(snapshot: snapshot, copyName: 'Culto (ao vivo com Fulano)');
    expect(saved.nome, 'Culto (ao vivo com Fulano)');
    expect(saved.salva, isTrue);
    expect(saved.syncStatus, PlaylistSyncStatus.pendingPush);
    expect(saved.entries, snapshot.entries);
    expect(saved.playlistId, isNot('remota')); // id novo, nunca o do gestor
  });

  test('snapshot vazio lança StateError', () async {
    final snapshot = LiveSnapshot(
      playlistId: 'r',
      name: 'n',
      entries: const [],
      focusKey: null,
    );
    await expectLater(
      SaveLiveCopy(_MemoryRepository()).call(snapshot: snapshot, copyName: 'x'),
      throwsStateError,
    );
  });
}
