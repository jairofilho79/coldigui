import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildPlaylistShareLocation', () {
    test('monta path com sharepdfs e sharename codificados', () {
      expect(
        buildPlaylistShareLocation(
          pdfIds: ['id-a', 'id-b'],
          shareName: 'Ensaio domingo',
        ),
        '/?sharepdfs=id-a%2Cid-b&sharename=Ensaio%20domingo',
      );
    });

    test('codifica acentos no nome', () {
      final location = buildPlaylistShareLocation(
        pdfIds: ['pdf1'],
        shareName: 'Cântico',
      );
      expect(location, contains('sharename=C%C3%A2ntico'));
    });

    test('lança se pdfIds vazio', () {
      expect(
        () => buildPlaylistShareLocation(pdfIds: [], shareName: 'Nome'),
        throwsArgumentError,
      );
    });

    test('lança se shareName vazio', () {
      expect(
        () => buildPlaylistShareLocation(pdfIds: ['a'], shareName: '  '),
        throwsArgumentError,
      );
    });
  });

  group('buildPlaylistShareUrl', () {
    test('concatena origin sem barra final', () {
      expect(
        buildPlaylistShareUrl(
          origin: 'https://plpcg.com',
          pdfIds: ['a', 'b'],
          shareName: 'Lista',
        ),
        'https://plpcg.com/?sharepdfs=a%2Cb&sharename=Lista',
      );
    });

    test('remove barra final do origin', () {
      expect(
        buildPlaylistShareUrl(
          origin: 'https://plpcg.com/',
          pdfIds: ['a'],
          shareName: 'Lista',
        ),
        'https://plpcg.com/?sharepdfs=a&sharename=Lista',
      );
    });
  });

  group('parsePdfIdsFromSharePdfs', () {
    test('preserva ordem', () {
      expect(
        parsePdfIdsFromSharePdfs('z,y,x'),
        ['z', 'y', 'x'],
      );
    });

    test('remove vazios e dedupe', () {
      expect(
        parsePdfIdsFromSharePdfs('a,,b, a ,b,c'),
        ['a', 'b', 'c'],
      );
    });

    test('trim em cada id', () {
      expect(
        parsePdfIdsFromSharePdfs(' id1 , id2 '),
        ['id1', 'id2'],
      );
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
    });

    test('retorna null se falta sharename', () {
      final uri = Uri.parse('/?sharepdfs=a,b');
      expect(parsePlaylistShareParams(uri), isNull);
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

    test('retorna null para input inválido', () {
      expect(extractShareParamsFromUserInput(''), isNull);
      expect(extractShareParamsFromUserInput('https://example.com'), isNull);
    });
  });

  group('stripPlaylistShareParams', () {
    test('remove sharepdfs e sharename', () {
      final uri = Uri.parse(
        'https://plpcg.com/?sharepdfs=a&sharename=Lista&pesquisa=teste',
      );
      final stripped = stripPlaylistShareParams(uri);
      expect(stripped.queryParameters.containsKey('sharepdfs'), isFalse);
      expect(stripped.queryParameters.containsKey('sharename'), isFalse);
      expect(stripped.queryParameters['pesquisa'], 'teste');
    });

    test('uri só com share fica sem query', () {
      final uri = Uri.parse('/?sharepdfs=a&sharename=Lista');
      final stripped = stripPlaylistShareParams(uri);
      expect(stripped.queryParameters, isEmpty);
    });
  });

  group('round-trip', () {
    test('location parseável recupera pdfIds e nome', () {
      const pdfIds = ['abc123', 'def456'];
      const shareName = 'Meu Ensaio';
      final location = buildPlaylistShareLocation(
        pdfIds: pdfIds,
        shareName: shareName,
      );
      final uri = Uri.parse('https://plpcg.com$location');
      final params = parsePlaylistShareParams(uri);
      expect(params?.shareName, shareName);
      expect(parsePdfIdsFromSharePdfs(params!.sharePdfs), pdfIds);
    });
  });
}
