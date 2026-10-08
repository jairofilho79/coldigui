import 'package:coldigui/features/carousel/presentation/utils/playlist_bar_tag_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPlaylistBarTag', () {
    test('retorna string vazia para tag vazia ou em branco', () {
      expect(formatPlaylistBarTag(''), '');
      expect(formatPlaylistBarTag('   '), '');
    });

    group('Mobile (< 600px ou isCompact: true)', () {
      test('abrevia tag e subtag no mínimo de 3 caracteres cada', () {
        expect(
          formatPlaylistBarTag('Coletânea · Clamor', barWidth: 360),
          'Col · Cla',
        );
        expect(
          formatPlaylistBarTag('Coletânea · Evangelização', isCompact: true),
          'Col · Eva',
        );
        expect(
          formatPlaylistBarTag('PES · 9.2026', barWidth: 400),
          'PES · 9.2',
        );
      });

      test('mantém tag ou subtag que já tenha 3 ou menos caracteres', () {
        expect(
          formatPlaylistBarTag('PES · Fé', barWidth: 360),
          'PES · Fé',
        );
      });

      test('abrevia tag única sem subtag em 3 caracteres', () {
        expect(
          formatPlaylistBarTag('Coletânea', barWidth: 360),
          'Col',
        );
        expect(
          formatPlaylistBarTag('PES', barWidth: 360),
          'PES',
        );
      });

      test('lida com mais de 2 níveis de subtag', () {
        expect(
          formatPlaylistBarTag('Coletânea · Seção · Longo', barWidth: 360),
          'Col · Seç · Lon',
        );
      });
    });

    group('Tablet Compacto (600px a 749px)', () {
      test('abrevia tag e subtag em 4 caracteres cada', () {
        expect(
          formatPlaylistBarTag('Coletânea · Clamor', barWidth: 600),
          'Cole · Clam',
        );
        expect(
          formatPlaylistBarTag('Coletânea · Evangelização', barWidth: 700),
          'Cole · Evan',
        );
        expect(
          formatPlaylistBarTag('PES · 9.2026', barWidth: 650),
          'PES · 9.20',
        );
      });

      test('tag única sem subtag permite até 10 caracteres', () {
        expect(
          formatPlaylistBarTag('Coletânea', barWidth: 650),
          'Coletânea',
        );
        expect(
          formatPlaylistBarTag('Coletânea Especial', barWidth: 650),
          'Coletânea',
        );
      });
    });

    group('Tablet Médio (750px a 899px)', () {
      test('abrevia tag e subtag em 6 caracteres cada', () {
        expect(
          formatPlaylistBarTag('Coletânea · Clamor', barWidth: 800),
          'Coletâ · Clamor',
        );
        expect(
          formatPlaylistBarTag('Coletânea · Evangelização', barWidth: 800),
          'Coletâ · Evange',
        );
        expect(
          formatPlaylistBarTag('PES · 9.2026', barWidth: 800),
          'PES · 9.2026',
        );
      });
    });

    group('Desktop / Telas Largas (>= 900px)', () {
      test('retorna a tag e subtag completas sem corte', () {
        expect(
          formatPlaylistBarTag('Coletânea · Clamor', barWidth: 900),
          'Coletânea · Clamor',
        );
        expect(
          formatPlaylistBarTag('Coletânea · Evangelização', barWidth: 1200),
          'Coletânea · Evangelização',
        );
        expect(
          formatPlaylistBarTag('Coletânea · Clamor', barWidth: null),
          'Coletânea · Clamor',
        );
      });
    });
  });
}
