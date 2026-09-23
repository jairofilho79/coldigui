import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_playlist_share_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/praise_short_id_unavailable_exception.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/praise_share_fixtures.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlists);

  final Map<String, SavedPlaylist> _playlists;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      _playlists[playlistId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _pdf = PlaylistEntry(
  id: praiseMaterialId('p-a', 'partitura.pdf'),
  kind: MaterialKind.pdf,
);
final _audio = PlaylistEntry(
  id: praiseMaterialId('p-b', 'audio.mp3'),
  kind: MaterialKind.audio,
);
final _chord = PlaylistEntry(
  id: praiseMaterialId('p-c', 'cifra.chord'),
  kind: MaterialKind.chord,
);
final _gesture = PlaylistEntry(
  id: praiseMaterialId('p-d', 'gestos.gestures'),
  kind: MaterialKind.gesture,
);
// YouTube não vive no espaço de paths — é Coldigom por construção.
const _youtube = PlaylistEntry(id: 'yt-1', kind: MaterialKind.youtube);
const _lyrics = PlaylistEntry(id: 'lyrics:p-e', kind: MaterialKind.lyrics);

// Id legado do acervo PLPCG (path fora de `assets/praises/`): o crosswalk
// nunca o resolve, então fica de fora do link em vez de falhar o share.
final _legacy = PlaylistEntry(
  id: encodePdfId('Coro/001 - Louvor antigo.pdf'),
  kind: MaterialKind.pdf,
);

GeneratePlaylistShareUrl _useCase(
  List<PlaylistEntry>? entries,
  Map<String, String> shortIds, {
  String nome = 'Culto de domingo',
  String? origin,
}) {
  final repository = _FakePlaylistRepository({
    if (entries != null)
      'p1': SavedPlaylist(
        playlistId: 'p1',
        nome: nome,
        entries: entries,
        createdAt: DateTime(2026, 9, 23),
      ),
  });
  String? lookup(String entryId) => shortIds[entryId];
  return origin == null
      ? GeneratePlaylistShareUrl(repository, praiseShortIdOf: lookup)
      : GeneratePlaylistShareUrl(
          repository,
          praiseShortIdOf: lookup,
          shareOrigin: origin,
        );
}

void main() {
  test('vetor do contrato: PDF, áudio e cifra, origem v2 por padrão', () async {
    final url = await _useCase(
      [_pdf, _audio, _chord],
      {_pdf.id: '1a2', _audio.id: '0c3', _chord.id: 'fff'},
    )(playlistId: 'p1');
    expect(url, 'https://v2.plpcg.com/?p=1a2-0c3-fff&n=Culto%20de%20domingo');
  });

  test('gesto, YouTube e letra também servem', () async {
    final url = await _useCase(
      [_gesture, _youtube, _lyrics],
      {_gesture.id: '0a1', _youtube.id: '0b2', _lyrics.id: '0c3'},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '0a1-0b2-0c3');
  });

  test(
    'dois materiais do mesmo praise viram o mesmo token duas vezes',
    () async {
      final url = await _useCase(
        [_pdf, _audio],
        {_pdf.id: '0a1', _audio.id: '0a1'},
        nome: 'Ensaio',
      )(playlistId: 'p1');
      expect(url, 'https://v2.plpcg.com/?p=0a1-0a1&n=Ensaio');
    },
  );

  test('entrada repetida repete o token, na ordem da lista', () async {
    final url = await _useCase(
      [_pdf, _audio, _pdf],
      {_pdf.id: '1a2', _audio.id: '0c3'},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '1a2-0c3-1a2');
  });

  test('maiúsculas e espaços do catálogo normalizam', () async {
    final url = await _useCase([_pdf], {_pdf.id: ' 1A2 '})(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '1a2');
  });

  test(
    'praise sem shortId → PraiseShortIdUnavailableException com os ids',
    () async {
      await expectLater(
        _useCase([_pdf, _audio, _chord], {_pdf.id: '1a2'})(playlistId: 'p1'),
        throwsA(
          isA<PraiseShortIdUnavailableException>().having(
            (e) => e.entryIds,
            'entryIds',
            [_audio.id, _chord.id],
          ),
        ),
      );
    },
  );

  test('shortId fora do padrão conta como em falta', () async {
    await expectLater(
      _useCase([_pdf, _audio], {_pdf.id: '12', _audio.id: 'zzz'})(
        playlistId: 'p1',
      ),
      throwsA(
        isA<PraiseShortIdUnavailableException>().having(
          (e) => e.entryIds,
          'entryIds',
          [_pdf.id, _audio.id],
        ),
      ),
    );
  });

  test('id legado fora do acervo Coldigom fica de fora do link', () async {
    final url = await _useCase(
      [_pdf, _legacy, _audio],
      {_pdf.id: '1a2', _audio.id: '0c3'},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '1a2-0c3');
  });

  test('generate conta os legados que ficaram de fora do link', () async {
    final link = await _useCase(
      [_pdf, _legacy, _audio, _legacy],
      {_pdf.id: '1a2', _audio.id: '0c3'},
    ).generate(playlistId: 'p1');
    expect(Uri.parse(link.url).queryParameters['p'], '1a2-0c3');
    expect(link.skippedCount, 2);
  });

  test('generate sem legados: skippedCount 0 e a mesma URL do call', () async {
    final useCase = _useCase([_pdf], {_pdf.id: '1a2'});
    final link = await useCase.generate(playlistId: 'p1');
    expect(link.skippedCount, 0);
    expect(link.url, await useCase(playlistId: 'p1'));
  });

  test(
    'YouTube gravado como unknown (lista legada) usa o token do índice',
    () async {
      const youtubeUnknown = PlaylistEntry(
        id: 'yt-1',
        kind: MaterialKind.unknown,
      );
      final url = await _useCase(
        [youtubeUnknown, _pdf],
        {youtubeUnknown.id: '0b2', _pdf.id: '1a2'},
      )(playlistId: 'p1');
      expect(Uri.parse(url).queryParameters['p'], '0b2-1a2');
    },
  );

  test('id que não decodifica (e não é YouTube) também fica de fora', () async {
    final url = await _useCase(
      [
        const PlaylistEntry(id: 'nao-e-base64!', kind: MaterialKind.unknown),
        _pdf,
      ],
      {_pdf.id: '1a2'},
    )(playlistId: 'p1');
    expect(Uri.parse(url).queryParameters['p'], '1a2');
  });

  test(
    'id Coldigom sem shortId ainda falha, mesmo ao lado de um legado',
    () async {
      await expectLater(
        _useCase([_legacy, _pdf], const {})(playlistId: 'p1'),
        throwsA(
          isA<PraiseShortIdUnavailableException>().having(
            (e) => e.entryIds,
            'entryIds',
            [_pdf.id],
          ),
        ),
      );
    },
  );

  test('só legados → EmptyPlaylistShareException', () async {
    await expectLater(
      _useCase([_legacy], const {})(playlistId: 'p1'),
      throwsA(isA<EmptyPlaylistShareException>()),
    );
  });

  test('origem configurável, sem barra final', () async {
    final url = await _useCase(
      [_pdf],
      {_pdf.id: '1a2'},
      origin: 'https://staging.plpcg.test/',
    )(playlistId: 'p1');
    expect(url, startsWith('https://staging.plpcg.test/?p=1a2&n='));
  });

  test('lista ausente → PlaylistNotFoundException', () async {
    await expectLater(
      _useCase(null, const {})(playlistId: 'p1'),
      throwsA(isA<PlaylistNotFoundException>()),
    );
  });

  test('lista vazia → EmptyPlaylistShareException', () async {
    await expectLater(
      _useCase(const [], const {})(playlistId: 'p1'),
      throwsA(isA<EmptyPlaylistShareException>()),
    );
  });
}
