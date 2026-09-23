import 'package:coldigui/core/constants/share_config.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('origem do link é o PWA v2', () {
    expect(ShareConfig.appOrigin, 'https://v2.plpcg.com');
  });

  group('isPraiseShortId', () {
    test('aceita 3 a 8 hex minúsculos', () {
      for (final id in ['000', 'fff', '1a2', '1000', 'abcdef12']) {
        expect(isPraiseShortId(id), isTrue, reason: id);
      }
    });

    test('recusa curto, longo, maiúsculo, não-hex e não-string', () {
      for (final id in <Object?>[
        '00',
        '123456789',
        '0A1',
        'g00',
        '',
        ' 0a1',
        12,
        null,
      ]) {
        expect(isPraiseShortId(id), isFalse, reason: '$id');
      }
    });
  });

  group('decodePraiseShareIds', () {
    test('normaliza maiúsculas, ignora inválidos e segmentos vazios, '
        'preserva ordem e repetição', () {
      expect(decodePraiseShareIds('0A1--fff- 1000 -zz-12-0a1-'), [
        '0a1',
        'fff',
        '1000',
        '0a1',
      ]);
    });

    test('string vazia vira lista vazia', () {
      expect(decodePraiseShareIds(''), isEmpty);
    });
  });

  group('buildPraiseShareUrl', () {
    test('vetor do contrato (spec §4.1)', () {
      expect(
        buildPraiseShareUrl(
          origin: ShareConfig.appOrigin,
          praiseShortIds: const ['1a2', '0c3', 'fff'],
          shareName: 'Culto de domingo',
        ),
        'https://v2.plpcg.com/?p=1a2-0c3-fff&n=Culto%20de%20domingo',
      );
    });

    test('tira a barra final da origem', () {
      expect(
        buildPraiseShareUrl(
          origin: 'https://v2.plpcg.com/',
          praiseShortIds: const ['0a1'],
          shareName: 'X',
        ),
        'https://v2.plpcg.com/?p=0a1&n=X',
      );
    });

    test('repetição fica: a lista pode repetir um louvor', () {
      expect(
        buildPraiseShareLocation(
          praiseShortIds: const ['0a1', '0a1'],
          shareName: 'X',
        ),
        '/?p=0a1-0a1&n=X',
      );
    });

    test('nome com &, #, acento e emoji faz round-trip pela URL', () {
      const nome = 'Culto & Ceia #1 — louvor 🎵';
      final uri = Uri.parse(
        buildPraiseShareUrl(
          origin: ShareConfig.appOrigin,
          praiseShortIds: const ['0a1', 'fff'],
          shareName: nome,
        ),
      );
      expect(uri.queryParameters['n'], nome);
      expect(uri.queryParameters['p'], '0a1-fff');
    });

    test('lança com lista vazia, token inválido ou nome em branco', () {
      expect(
        () =>
            buildPraiseShareLocation(praiseShortIds: const [], shareName: 'X'),
        throwsArgumentError,
      );
      expect(
        () => buildPraiseShareLocation(
          praiseShortIds: const ['0A1'],
          shareName: 'X',
        ),
        throwsArgumentError,
      );
      expect(
        () => buildPraiseShareLocation(
          praiseShortIds: const ['0a1'],
          shareName: '  ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('parsePlaylistShareParams', () {
    test('p + n → tokens normalizados, na ordem, e nome decodificado', () {
      final params = parsePlaylistShareParams(
        Uri.parse(
          'https://v2.plpcg.com/?p=0A1-fff--zz-0a1&n=Culto%20de%20domingo',
        ),
      )!;
      expect(params.isLegacy, isFalse);
      expect(params.praiseShortIds, ['0a1', 'fff', '0a1']);
      expect(params.shareName, 'Culto de domingo');
      expect(params.hasMaterial, isTrue);
    });

    test('p sem token válido é link sem material (aviso, D.6)', () {
      final params = parsePlaylistShareParams(Uri.parse('/?p=zz-12&n=X'))!;
      expect(params.isLegacy, isFalse);
      expect(params.hasMaterial, isFalse);
    });

    test('p sem n é link com nome vazio', () {
      final params = parsePlaylistShareParams(Uri.parse('/?p=0a1'))!;
      expect(params.shareName, '');
      expect(params.praiseShortIds, ['0a1']);
    });

    test('p vence params antigos na mesma URL', () {
      final params = parsePlaylistShareParams(
        Uri.parse('/?p=0a1&n=X&s=1a2f&sharename=Y'),
      )!;
      expect(params.isLegacy, isFalse);
      expect(params.praiseShortIds, ['0a1']);
    });

    test('cada param antigo, sem p, é link antigo', () {
      for (final query in [
        's=1a2f-0000&n=Culto',
        'sharepdfs=a',
        'shareitems=p%3Aa',
        'shareaudios=a',
        'sharepdfs=a&sharename=Ensaio',
      ]) {
        final params = parsePlaylistShareParams(Uri.parse('/?$query'));
        expect(params?.isLegacy, isTrue, reason: query);
        expect(params?.hasMaterial, isFalse, reason: query);
      }
    });

    test('s só conta com n; sharename sozinho não é link de lista', () {
      expect(parsePlaylistShareParams(Uri.parse('/?s=20')), isNull);
      expect(parsePlaylistShareParams(Uri.parse('/?sharename=Ensaio')), isNull);
      expect(
        parsePlaylistShareParams(Uri.parse('/?s=20&sharename=Ensaio')),
        isNull,
      );
    });

    test('link curto antigo /l/<código> é link antigo', () {
      for (final url in [
        'https://plpcg.com/l/abc123',
        'https://v2.plpcg.com/l/abc123?x=1',
        '/l/abc123',
      ]) {
        final params = parsePlaylistShareParams(Uri.parse(url));
        expect(params?.isLegacy, isTrue, reason: url);
      }
      expect(parsePlaylistShareParams(Uri.parse('/lista/abc')), isNull);
    });

    test('esquema plpcg:/// antigo também é link antigo', () {
      expect(
        parsePlaylistShareParams(Uri.parse('plpcg:///?s=1a2f&n=Culto'))
            ?.isLegacy,
        isTrue,
      );
    });

    test('n sozinho ou URL comum não é link de lista', () {
      expect(parsePlaylistShareParams(Uri.parse('/?n=Culto')), isNull);
      expect(parsePlaylistShareParams(Uri.parse('/?pesquisa=aleluia')), isNull);
      expect(parsePlaylistShareParams(Uri.parse('/')), isNull);
    });

    test('não lança com "%" malformado noutro param', () {
      final params = parsePlaylistShareParams(
        Uri.parse('/?p=0a1&n=X&junk=%E0%A4%A'),
      );
      expect(params?.praiseShortIds, ['0a1']);
    });
  });

  group('stripPlaylistShareParams', () {
    test('remove p, n e todos os antigos; preserva o resto', () {
      final stripped = stripPlaylistShareParams(
        Uri.parse(
          '/?pesquisa=x&p=0a1&n=Y&s=1&sharepdfs=a&shareitems=b'
          '&shareaudios=c&sharename=d',
        ),
      );
      expect(stripped.queryParameters, {'pesquisa': 'x'});
    });

    test('URL só com share fica sem query', () {
      expect(
        stripPlaylistShareParams(Uri.parse('/?p=0a1&n=Y')).queryParameters,
        isEmpty,
      );
    });

    test('não lança com "%" malformado', () {
      expect(
        stripPlaylistShareParams(Uri.parse('/?p=0a1&junk=%E0%A4%A'))
            .queryParameters,
        isEmpty,
      );
    });
  });

  group('extractShareParamsFromUserInput', () {
    test('aceita URL completa', () {
      expect(
        extractShareParamsFromUserInput(
          'https://v2.plpcg.com/?p=0a1-fff&n=Ensaio',
        )?.praiseShortIds,
        ['0a1', 'fff'],
      );
    });

    test('aceita query crua, com ou sem "?"', () {
      expect(
        extractShareParamsFromUserInput('p=0a1&n=Ensaio')?.praiseShortIds,
        ['0a1'],
      );
      expect(
        extractShareParamsFromUserInput('?p=0a1&n=Ensaio')?.praiseShortIds,
        ['0a1'],
      );
    });

    test('aceita texto com prefixo antes do "?"', () {
      final params = extractShareParamsFromUserInput(
        'abre isto: v2.plpcg.com/?p=0a1&n=Ensaio',
      );
      expect(params?.praiseShortIds, ['0a1']);
      expect(params?.shareName, 'Ensaio');
    });

    test('link antigo colado devolve params antigos', () {
      expect(
        extractShareParamsFromUserInput(
          'https://plpcg.com/?s=1a2f-0000&n=Culto',
        )?.isLegacy,
        isTrue,
      );
      expect(
        extractShareParamsFromUserInput('sharepdfs=a&sharename=X')?.isLegacy,
        isTrue,
      );
    });

    test('p sem token válido devolve params sem material (aviso)', () {
      final params = extractShareParamsFromUserInput(
        'https://v2.plpcg.com/?p=zz&n=X',
      );
      expect(params, isNotNull);
      expect(params!.isLegacy, isFalse);
      expect(params.hasMaterial, isFalse);
    });

    test('legenda do folheto com «?» no nome: lê o link, não o nome', () {
      const nome = 'Quem é Deus?';
      final url = buildPraiseShareUrl(
        origin: 'https://v2.plpcg.com',
        praiseShortIds: const ['0a1', 'fff'],
        shareName: nome,
      );
      final params = extractShareParamsFromUserInput('$nome\n\n$url');
      expect(params?.praiseShortIds, ['0a1', 'fff']);
      expect(params?.shareName, nome);
    });

    test('legenda com «?» no nome e link antigo → link antigo', () {
      expect(
        extractShareParamsFromUserInput(
          'Quem é Deus?\n\nhttps://plpcg.com/?s=1a2f&n=Quem%20%C3%A9%20Deus%3F',
        )?.isLegacy,
        isTrue,
      );
    });

    test('link curto antigo /l/<código> colado → link antigo', () {
      expect(
        extractShareParamsFromUserInput('https://plpcg.com/l/abc123')?.isLegacy,
        isTrue,
      );
      expect(
        extractShareParamsFromUserInput('Culto\n\nhttps://plpcg.com/l/abc123')
            ?.isLegacy,
        isTrue,
      );
    });

    test('s sem n colado não é link de lista', () {
      expect(extractShareParamsFromUserInput('?s=20'), isNull);
    });

    test('input que não é link de lista → null', () {
      expect(extractShareParamsFromUserInput('https://example.com'), isNull);
      expect(extractShareParamsFromUserInput('   '), isNull);
    });
  });
}
