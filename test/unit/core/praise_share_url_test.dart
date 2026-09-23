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
}
