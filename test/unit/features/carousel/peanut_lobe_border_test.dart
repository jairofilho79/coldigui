import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 300.0;
const _r = 24.0;
const _d = peanutLobeTipInset;

Path _lobe(LobePosition p, double h) =>
    peanutLobePath(const Offset(0, 0) & Size(_w, h), p, radius: _r);

void main() {
  test('lobePositionAt: primeiro, meio e último', () {
    expect(
      [for (var i = 0; i < 3; i++) lobePositionAt(i, 3)],
      [LobePosition.first, LobePosition.middle, LobePosition.last],
    );
    expect(
      [for (var i = 0; i < 2; i++) lobePositionAt(i, 2)],
      [LobePosition.first, LobePosition.last],
    );
  });

  test('primeiro gomo: topo de pílula, bico a 10 px na base', () {
    final path = _lobe(LobePosition.first, 58);

    expect(path.contains(const Offset(_w / 2, 29)), isTrue);
    // Canto de cima arredondado (pílula).
    expect(path.contains(const Offset(_w - 1, 1)), isFalse);
    expect(path.contains(const Offset(1, 1)), isFalse);
    // Na linha da junta, o preenchimento vai até o bico e não além.
    expect(path.contains(const Offset(_w - _d - 1, 57.5)), isTrue);
    expect(path.contains(const Offset(_w - 2, 57.5)), isFalse);
    expect(path.contains(const Offset(_d + 1, 57.5)), isTrue);
    expect(path.contains(const Offset(2, 57.5)), isFalse);
  });

  test('último gomo: bico no topo, base de pílula', () {
    final path = _lobe(LobePosition.last, 58);

    expect(path.contains(const Offset(_w - _d - 1, 0.5)), isTrue);
    expect(path.contains(const Offset(_w - 2, 0.5)), isFalse);
    expect(path.contains(const Offset(_w - 1, 57)), isFalse);
  });

  test('gomo do meio: bico em cima e embaixo, lateral cheia no meio', () {
    final path = _lobe(LobePosition.middle, 40);

    expect(path.contains(const Offset(_w - 2, 0.5)), isFalse);
    expect(path.contains(const Offset(_w - 2, 39.5)), isFalse);
    expect(path.contains(const Offset(_w - 1, 20)), isTrue);
  });

  test('gomo alto (trecho da letra): lateral reta, bico no mesmo lugar', () {
    final path = _lobe(LobePosition.first, 100);

    // Entre a pílula (24) e o começo da curva da junta (100 − 26 = 74).
    for (final y in [30.0, 50.0, 70.0]) {
      expect(path.contains(Offset(_w - 0.5, y)), isTrue, reason: 'y=$y');
      expect(path.contains(Offset(0.5, y)), isTrue, reason: 'y=$y');
    }
    expect(path.contains(const Offset(_w - _d - 1, 99.5)), isTrue);
    expect(path.contains(const Offset(_w - 2, 99.5)), isFalse);
  });

  test('borda: 2 px como o Border.all de hoje; igualdade por posição', () {
    const border = PeanutLobeBorder(position: LobePosition.last, radius: _r);

    expect(border.dimensions, const EdgeInsets.all(2));
    expect(
      border,
      const PeanutLobeBorder(position: LobePosition.last, radius: _r),
    );
    expect(
      border ==
          const PeanutLobeBorder(position: LobePosition.first, radius: _r),
      isFalse,
    );
    // O arco da junta passa da lateral por ~1e-6 px (erro de ponto flutuante
    // no ponto de tangência); daí a tolerância.
    expect(
      border.getOuterPath(const Offset(0, 0) & const Size(_w, 58)).getBounds(),
      rectMoreOrLessEquals(
        const Offset(0, 0) & const Size(_w, 58),
        epsilon: 1e-3,
      ),
    );
  });
}
