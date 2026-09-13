import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

const _pdfA = PlaylistEntry(id: 'id-a', kind: MaterialKind.pdf);
const _pdfB = PlaylistEntry(id: 'id-b', kind: MaterialKind.pdf);
const _audio1 = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);
const _chord1 = PlaylistEntry(id: 'cif-1', kind: MaterialKind.chord);

/// `encodePdfId('assets/chords/a.chord')` — id cuja extensão diz `chord`.
const _chordId = 'YXNzZXRzL2Nob3Jkcy9hLmNob3Jk';

/// `encodePdfId('assets/gestures/a.gestures')`.
const _gestureId = 'YXNzZXRzL2dlc3R1cmVzL2EuZ2VzdHVyZXM';

/// `encodePdfId('assets/praises/a/001.mp3')` — extensão de áudio.
const _audioExtId = 'YXNzZXRzL3ByYWlzZXMvYS8wMDEubXAz';

void main() {
  group('encodeShareItems', () {
    test('emite prefixo:id na ordem única', () {
      expect(
        encodeShareItems(const [_pdfA, _audio1, _chord1]),
        'p:id-a,a:aud-1,c:cif-1',
      );
    });

    test('cobre os seis prefixos', () {
      expect(
        encodeShareItems(const [
          PlaylistEntry(id: '1', kind: MaterialKind.pdf),
          PlaylistEntry(id: '2', kind: MaterialKind.chord),
          PlaylistEntry(id: '3', kind: MaterialKind.audio),
          PlaylistEntry(id: '4', kind: MaterialKind.youtube),
          PlaylistEntry(id: '5', kind: MaterialKind.gesture),
          PlaylistEntry(id: '6', kind: MaterialKind.unknown),
        ]),
        'p:1,c:2,a:3,y:4,g:5,u:6',
      );
    });

    test('lista vazia vira string vazia', () {
      expect(encodeShareItems(const []), '');
    });
  });

  group('decodeShareItems', () {
    test('round-trip preserva ordem e tipo', () {
      const entries = [_pdfA, _audio1, _chord1];
      expect(decodeShareItems(encodeShareItems(entries)), entries);
    });

    test('token sem ":" devolve null', () {
      expect(decodeShareItems('p:id-a,id-b'), isNull);
    });

    test('prefixo desconhecido devolve null', () {
      expect(decodeShareItems('p:id-a,z:id-b'), isNull);
    });

    test('token com id vazio devolve null', () {
      expect(decodeShareItems('p:id-a,a:'), isNull);
    });

    test('token com prefixo vazio devolve null', () {
      expect(decodeShareItems(':id-a'), isNull);
    });

    test('string vazia devolve null', () {
      expect(decodeShareItems(''), isNull);
      expect(decodeShareItems('   '), isNull);
    });

    test('segmentos vazios são tolerados', () {
      expect(decodeShareItems('p:id-a,,a:aud-1,'), const [_pdfA, _audio1]);
    });

    test('id repetido preserva as duas ocorrências (a lista pode repetir)', () {
      expect(decodeShareItems('p:id-a,p:id-b,p:id-a'), const [
        _pdfA,
        _pdfB,
        _pdfA,
      ]);
    });

    test('faz trim de cada token', () {
      expect(decodeShareItems(' p:id-a , a:aud-1 '), const [_pdfA, _audio1]);
    });

    test('kind genérico é refinado pela extensão (resolveWireKind)', () {
      // `p:` num id de `.chord` — URL escrita à mão ou montada por quem só
      // sabe dizer "partitura". Normaliza como o caminho de sync.
      expect(decodeShareItems('p:$_chordId'), const [
        PlaylistEntry(id: _chordId, kind: MaterialKind.chord),
      ]);
      expect(decodeShareItems('u:$_gestureId'), const [
        PlaylistEntry(id: _gestureId, kind: MaterialKind.gesture),
      ]);
    });

    test('audio declarado atravessa a extensão intocado (A8)', () {
      expect(decodeShareItems('a:$_chordId'), const [
        PlaylistEntry(id: _chordId, kind: MaterialKind.audio),
      ]);
    });
  });

  group('buildPlaylistShareLocation', () {
    test('emite shareitems + sharename + os dois legados', () {
      expect(
        buildPlaylistShareLocation(
          entries: const [_pdfA, _audio1, _pdfB],
          shareName: 'Ensaio domingo',
        ),
        '/?shareitems=p%3Aid-a%2Ca%3Aaud-1%2Cp%3Aid-b'
        '&sharename=Ensaio%20domingo'
        '&sharepdfs=id-a%2Cid-b'
        '&shareaudios=aud-1',
      );
    });

    test('só partituras omite shareaudios', () {
      final location = buildPlaylistShareLocation(
        entries: const [_pdfA],
        shareName: 'Lista',
      );
      expect(location, contains('sharepdfs=id-a'));
      expect(location, isNot(contains('shareaudios=')));
    });

    test('só áudio omite sharepdfs', () {
      final location = buildPlaylistShareLocation(
        entries: const [_audio1],
        shareName: 'Lista audio',
      );
      expect(location, contains('shareaudios=aud-1'));
      expect(location, isNot(contains('sharepdfs=')));
    });

    test('codifica acentos no nome', () {
      final location = buildPlaylistShareLocation(
        entries: const [_pdfA],
        shareName: 'Cântico',
      );
      expect(location, contains('sharename=C%C3%A2ntico'));
    });

    test('lança se entries vazio', () {
      expect(
        () => buildPlaylistShareLocation(entries: const [], shareName: 'Nome'),
        throwsArgumentError,
      );
    });

    test('lança se shareName vazio', () {
      expect(
        () =>
            buildPlaylistShareLocation(entries: const [_pdfA], shareName: '  '),
        throwsArgumentError,
      );
    });
  });

  group('buildPlaylistShareUrl (wrapper legado)', () {
    test('concatena origin sem barra final e emite shareitems', () {
      final url = buildPlaylistShareUrl(
        origin: 'https://plpcg.com',
        pdfIds: const ['a', 'b'],
        shareName: 'Lista',
      );
      expect(url, startsWith('https://plpcg.com/?'));
      expect(url, contains('sharepdfs=a%2Cb'));
      expect(url, contains('sharename=Lista'));
      expect(url, contains('shareitems='));
    });

    test('remove barra final do origin', () {
      final url = buildPlaylistShareUrl(
        origin: 'https://plpcg.com/',
        pdfIds: const ['a'],
        shareName: 'Lista',
      );
      expect(url, startsWith('https://plpcg.com/?'));
    });

    test('id com extensão de áudio em pdfIds cai na face de áudio', () {
      // O que o dartdoc do wrapper avisa: `pdfIds` não declara tipo, então a
      // extensão vence e o id sai em `a:`/`shareaudios`.
      final url = buildPlaylistShareUrl(
        origin: 'https://plpcg.com',
        pdfIds: const [_audioExtId],
        shareName: 'Lista',
      );
      expect(url, contains('shareitems=a%3A$_audioExtId'));
      expect(url, contains('shareaudios=$_audioExtId'));
      expect(url, isNot(contains('sharepdfs=')));
    });

    test('audioIds do wrapper viram entradas de áudio', () {
      final url = buildPlaylistShareUrl(
        origin: 'https://plpcg.com',
        pdfIds: const [],
        audioIds: const ['aud-1'],
        shareName: 'Lista',
      );
      final params = parsePlaylistShareParams(Uri.parse(url));
      expect(params!.entries, const [_audio1]);
    });
  });

  group('buildPlaylistShareUrlFromEntries', () {
    test('preserva a ordem intercalada na URL absoluta', () {
      final url = buildPlaylistShareUrlFromEntries(
        origin: 'https://plpcg.com/',
        entries: const [_pdfA, _audio1, _pdfB],
        shareName: 'Lista',
      );
      final params = parsePlaylistShareParams(Uri.parse(url));
      expect(params!.entries, const [_pdfA, _audio1, _pdfB]);
    });
  });

  group('parsePdfIdsFromSharePdfs', () {
    test('preserva ordem', () {
      expect(parsePdfIdsFromSharePdfs('z,y,x'), ['z', 'y', 'x']);
    });

    test('remove vazios e dedupe', () {
      expect(parsePdfIdsFromSharePdfs('a,,b, a ,b,c'), ['a', 'b', 'c']);
    });

    test('trim em cada id', () {
      expect(parsePdfIdsFromSharePdfs(' id1 , id2 '), ['id1', 'id2']);
    });
  });

  group('parsePlaylistShareParams', () {
    test('extrai params de uri completa', () {
      final uri = Uri.parse(
        'https://plpcg.com/?sharepdfs=a%2Cb&sharename=Ensaio',
      );
      final params = parsePlaylistShareParams(uri);
      expect(params?.sharePdfs, 'a,b');
      expect(params?.shareName, 'Ensaio');
      expect(params?.shareItems, isNull);
    });

    test('retorna null se falta sharename', () {
      final uri = Uri.parse('/?sharepdfs=a,b');
      expect(parsePlaylistShareParams(uri), isNull);
    });

    test('shareitems sozinho já basta (sem legados)', () {
      final uri = Uri.parse(
        '/?shareitems=p%3Aid-a%2Ca%3Aaud-1&sharename=Ensaio',
      );
      final params = parsePlaylistShareParams(uri);
      expect(params, isNotNull);
      expect(params!.entries, const [_pdfA, _audio1]);
    });

    test('shareitems vence os legados e preserva a ordem intercalada', () {
      final uri = Uri.parse(
        '/?shareitems=p%3Aid-a%2Ca%3Aaud-1%2Cp%3Aid-b'
        '&sharename=Ensaio&sharepdfs=id-a%2Cid-b&shareaudios=aud-1',
      );
      final params = parsePlaylistShareParams(uri);
      expect(params!.entries, const [_pdfA, _audio1, _pdfB]);
    });

    test('URL só com legados (app antigo) → pdfs + audios', () {
      final uri = Uri.parse(
        '/?sharename=Ensaio&sharepdfs=id-a%2Cid-b&shareaudios=aud-1',
      );
      final params = parsePlaylistShareParams(uri);
      expect(params!.entries, const [
        PlaylistEntry(id: 'id-a', kind: MaterialKind.unknown),
        PlaylistEntry(id: 'id-b', kind: MaterialKind.unknown),
        _audio1,
      ]);
    });

    test('shareitems inválido cai nos legados', () {
      final uri = Uri.parse(
        '/?shareitems=lixo&sharename=Ensaio&sharepdfs=id-a',
      );
      final params = parsePlaylistShareParams(uri);
      expect(params!.entries, const [
        PlaylistEntry(id: 'id-a', kind: MaterialKind.unknown),
      ]);
    });

    test('shareitems inválido sem legados devolve entries vazio', () {
      final uri = Uri.parse('/?shareitems=lixo&sharename=Ensaio');
      final params = parsePlaylistShareParams(uri);
      expect(
        params,
        isNotNull,
        reason: 'há sharename: é um share, só que ruim',
      );
      expect(params!.entries, isEmpty);
    });

    test('URL só com sharename devolve params com entries vazio (D.6)', () {
      // "Não é share" (null) e "share sem materiais" são coisas diferentes: a
      // segunda tem que virar aviso, não sumiço silencioso.
      final params = parsePlaylistShareParams(Uri.parse('/?sharename=Ensaio'));
      expect(params, isNotNull);
      expect(params!.shareName, 'Ensaio');
      expect(params.entries, isEmpty);
    });

    test('URL sem nenhum param de share continua devolvendo null', () {
      expect(parsePlaylistShareParams(Uri.parse('/?pesquisa=x')), isNull);
    });

    test('não lança com "%" malformado em outro param', () {
      final uri = Uri.parse(
        '/?pesquisa=100%&shareitems=p%3Aid-a&sharename=Ensaio',
      );
      final params = parsePlaylistShareParams(uri);
      expect(params!.entries, const [_pdfA]);
    });
  });

  group('extractShareParamsFromUserInput', () {
    test('aceita URL completa', () {
      final params = extractShareParamsFromUserInput(
        'https://plpcg.com/?sharepdfs=x&sharename=Teste',
      );
      expect(params?.sharePdfs, 'x');
      expect(params?.shareName, 'Teste');
    });

    test('aceita query string sem origin', () {
      final params = extractShareParamsFromUserInput(
        'sharepdfs=a,b&sharename=Lista',
      );
      expect(params?.sharePdfs, 'a,b');
      expect(params?.shareName, 'Lista');
    });

    test('aceita fragmento só com shareitems', () {
      final params = extractShareParamsFromUserInput(
        'shareitems=p:id-a,a:aud-1&sharename=Lista',
      );
      expect(params, isNotNull);
      expect(params!.entries, const [_pdfA, _audio1]);
    });

    test('aceita fragmento colado com prefixo antes do "?"', () {
      final params = extractShareParamsFromUserInput(
        'abre isto: plpcg.com/?shareitems=p:id-a&sharename=Lista',
      );
      expect(params, isNotNull);
      expect(params!.entries, const [_pdfA]);
    });

    test('retorna null para input inválido', () {
      expect(extractShareParamsFromUserInput(''), isNull);
      expect(extractShareParamsFromUserInput('https://example.com'), isNull);
    });
  });

  group('stripPlaylistShareParams', () {
    test('remove sharepdfs, sharename e shareitems', () {
      final uri = Uri.parse(
        'https://plpcg.com/?shareitems=p%3Aa&sharepdfs=a&sharename=Lista'
        '&pesquisa=teste',
      );
      final stripped = stripPlaylistShareParams(uri);
      expect(stripped.queryParameters.containsKey('shareitems'), isFalse);
      expect(stripped.queryParameters.containsKey('sharepdfs'), isFalse);
      expect(stripped.queryParameters.containsKey('sharename'), isFalse);
      expect(stripped.queryParameters['pesquisa'], 'teste');
    });

    test('uri só com share fica sem query', () {
      final uri = Uri.parse('/?shareitems=p%3Aa&sharepdfs=a&sharename=Lista');
      final stripped = stripPlaylistShareParams(uri);
      expect(stripped.queryParameters, isEmpty);
    });

    test('não lança com "%" malformado', () {
      final uri = Uri.parse('/?pesquisa=100%&sharepdfs=a&sharename=Lista');
      final stripped = stripPlaylistShareParams(uri);
      expect(stripped.query, isNot(contains('sharepdfs')));
    });
  });

  group('round-trip', () {
    test('location parseável recupera entries, pdfIds e nome', () {
      const entries = [_pdfA, _audio1, _chord1];
      const shareName = 'Meu Ensaio';
      final location = buildPlaylistShareLocation(
        entries: entries,
        shareName: shareName,
      );
      final uri = Uri.parse('https://plpcg.com$location');
      final params = parsePlaylistShareParams(uri);
      expect(params?.shareName, shareName);
      expect(params?.entries, entries);
      expect(parsePdfIdsFromSharePdfs(params!.sharePdfs), ['id-a', 'cif-1']);
      expect(parseAudioIdsFromShareAudios(params.shareAudios), ['aud-1']);
    });
  });
}
