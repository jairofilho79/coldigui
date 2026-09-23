import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/praise_share_fixtures.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlist);

  final SavedPlaylist _playlist;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      playlistId == _playlist.playlistId ? _playlist : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  // Material movido (desvio 2 do spec de 18/09): o path aponta a pasta de
  // `p-outro`, mas o material pertence ao praise `p1` no catálogo.
  final movedPdfId = praiseMaterialId('p-outro', 'partitura.pdf');
  final ownAudioId = praiseMaterialId('p1', 'audio.mp3');
  final index = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      pdfs: [praisePdf(praiseId: 'p1', pdfId: movedPdfId)],
      audios: [praiseAudio(praiseId: 'p1', audioId: ownAudioId)],
    ),
    praiseGroup(
      praiseId: 'p-outro',
      shortId: 'fff',
      pdfs: [
        praisePdf(
          praiseId: 'p-outro',
          pdfId: praiseMaterialId('p-outro', 'coro.pdf'),
        ),
      ],
    ),
    praiseGroup(
      praiseId: 'p-sem-id',
      audios: [
        praiseAudio(
          praiseId: 'p-sem-id',
          audioId: praiseMaterialId('p-sem-id', 'audio.mp3'),
        ),
      ],
    ),
  ]);

  Future<String> share(ColdigomSearchIndex index, List<PlaylistEntry> entries) {
    final container = ProviderContainer(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(
          _FakePlaylistRepository(
            SavedPlaylist(
              playlistId: 'p1',
              nome: 'Ensaio',
              entries: entries,
              createdAt: DateTime(2026, 9, 23),
            ),
          ),
        ),
        coldigomSearchIndexProvider.overrideWithValue(index),
      ],
    );
    addTearDown(container.dispose);
    return container.read(generatePlaylistShareUrlProvider)(playlistId: 'p1');
  }

  test('sentinela do contrato C4: o índice resolve shortId e material', () {
    expect(index.groupByShortId('0a1')?.groupId, 'p1');
    expect(index.groupForMaterialId(movedPdfId)?.groupId, 'p1');
    expect(index.groupForMaterialId(ownAudioId)?.groupId, 'p1');
  });

  test('material movido usa o praise do catálogo, não o do path', () async {
    final url = await share(index, [
      PlaylistEntry(id: movedPdfId, kind: MaterialKind.pdf),
      PlaylistEntry(id: ownAudioId, kind: MaterialKind.audio),
    ]);
    expect(url, 'https://v2.plpcg.com/?p=0a1-0a1&n=Ensaio');
  });

  test('id legado órfão fica de fora; os do catálogo seguem', () async {
    final url = await share(index, [
      PlaylistEntry(
        id: encodePdfId('Coro/001 - Louvor antigo.pdf'),
        kind: MaterialKind.pdf,
      ),
      PlaylistEntry(id: ownAudioId, kind: MaterialKind.audio),
    ]);
    expect(url, 'https://v2.plpcg.com/?p=0a1&n=Ensaio');
  });

  test(
    'índice ainda vazio (arranque a frio) → PraiseShortIdUnavailableException',
    () async {
      await expectLater(
        share(ColdigomSearchIndex.empty, [
          PlaylistEntry(id: ownAudioId, kind: MaterialKind.audio),
        ]),
        throwsA(isA<PraiseShortIdUnavailableException>()),
      );
    },
  );

  test(
    'praise sem shortId no catálogo → PraiseShortIdUnavailableException',
    () async {
      await expectLater(
        share(index, [
          PlaylistEntry(
            id: praiseMaterialId('p-sem-id', 'audio.mp3'),
            kind: MaterialKind.audio,
          ),
        ]),
        throwsA(isA<PraiseShortIdUnavailableException>()),
      );
    },
  );
}
