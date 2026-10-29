import 'dart:math' as math;

import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/painting.dart';

/// Posição do gomo no amendoim (spec louvores-agrupados §6.1): o primeiro
/// tem topo de pílula, o último base de pílula; as juntas são meio-coração.
enum LobePosition { first, middle, last }

/// Posição do gomo [index] num amendoim de [count] gomos (`count` ≥ 2).
LobePosition lobePositionAt(int index, int count) {
  if (index == 0) return LobePosition.first;
  if (index == count - 1) return LobePosition.last;
  return LobePosition.middle;
}

/// Recuo do bico em relação à lateral, na linha da junta (`d`).
const peanutLobeTipInset = 10.0;

/// Distância vertical máxima entre a junta e o ponto onde a curva encontra a
/// lateral (`a`).
const peanutLobeJunctionReach = 26.0;

const _strokeWidth = 2.0;

/// Contorno fechado do gomo em [rect]: pílula de raio [radius] nas pontas do
/// amendoim; nas juntas, um arco convexo de cada lado, da lateral até o bico
/// recuado [peanutLobeTipInset] — o topo de um coração. Um gomo mais alto só
/// ganha trecho reto na lateral.
///
/// É também a silhueta que `PeanutClusterColumn` usa para a sombra.
Path peanutLobePath(
  Rect rect,
  LobePosition position, {
  required double radius,
}) => _lobePath(rect, position, radius: radius, outline: false);

/// [outline] `true`: o mesmo caminho, mas sem o trecho da junta entre os
/// bicos (a costura é pintada à parte, pelo gomo de baixo) e sem fechar.
Path _lobePath(
  Rect rect,
  LobePosition position, {
  required double radius,
  required bool outline,
}) {
  const d = peanutLobeTipInset;
  final h = rect.height;
  final a = position == LobePosition.middle
      ? math.min(peanutLobeJunctionReach, h / 2)
      : math.max(1.0, math.min(peanutLobeJunctionReach, h - radius));
  final junction = Radius.circular((d * d + a * a) / (2 * d));
  final pill = Radius.circular(radius);
  final topIsPill = position == LobePosition.first;
  final bottomIsPill = position == LobePosition.last;

  final path = Path();
  void seam(double x, double y) =>
      outline ? path.moveTo(x, y) : path.lineTo(x, y);

  // Topo, da lateral esquerda à direita (sentido horário).
  final start = Offset(rect.left, rect.top + (topIsPill ? radius : a));
  path.moveTo(start.dx, start.dy);
  if (topIsPill) {
    path
      ..arcToPoint(Offset(rect.left + radius, rect.top), radius: pill)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius), radius: pill);
  } else {
    path.arcToPoint(Offset(rect.left + d, rect.top), radius: junction);
    seam(rect.right - d, rect.top);
    path.arcToPoint(Offset(rect.right, rect.top + a), radius: junction);
  }

  // Lateral direita e base, da direita à esquerda.
  if (bottomIsPill) {
    path
      ..lineTo(rect.right, rect.bottom - radius)
      ..arcToPoint(Offset(rect.right - radius, rect.bottom), radius: pill)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius), radius: pill);
  } else {
    path
      ..lineTo(rect.right, rect.bottom - a)
      ..arcToPoint(Offset(rect.right - d, rect.bottom), radius: junction);
    seam(rect.left + d, rect.bottom);
    path.arcToPoint(Offset(rect.left, rect.bottom - a), radius: junction);
  }

  // Lateral esquerda, de volta ao começo.
  path.lineTo(start.dx, start.dy);
  if (!outline) path.close();
  return path;
}

/// Borda de **um** gomo do amendoim (variante E «Coração pleno»): contorno
/// dourado de 2 px por dentro, só nas laterais e nas pontas; na junta, só a
/// costura dourada a 60 %, de bico a bico, pintada pelo gomo de baixo (topo
/// de `middle` e `last`) para não pintar duas vezes.
///
/// Gomos empilhados sem espaço formam o amendoim; o preenchimento
/// (`AppColors.title`) vem da `ShapeDecoration` que usa esta borda.
class PeanutLobeBorder extends ShapeBorder {
  const PeanutLobeBorder({required this.position, required this.radius});

  final LobePosition position;

  /// Raio das pontas de pílula — `carouselChipModalRadius`.
  final double radius;

  /// Igual ao `Border.all(width: 2)` do chip solto: o `Container` soma isto
  /// ao padding, e com zero o gomo ficaria 4 px mais baixo que o chip.
  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(_strokeWidth);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      peanutLobePath(rect, position, radius: radius);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      peanutLobePath(
        rect.deflate(_strokeWidth),
        position,
        radius: math.max(0, radius - _strokeWidth),
      );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Traço de 4 px centrado no contorno e recortado pelo próprio gomo = 2 px
    // por dentro, e o bico sai exatamente no ponto do preenchimento.
    canvas
      ..save()
      ..clipPath(getOuterPath(rect))
      ..drawPath(
        _lobePath(rect, position, radius: radius, outline: true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth * 2
          ..color = AppColors.gold,
      )
      ..restore();

    if (position != LobePosition.first) {
      final y = rect.top + 0.5;
      canvas.drawLine(
        Offset(rect.left + peanutLobeTipInset, y),
        Offset(rect.right - peanutLobeTipInset, y),
        Paint()
          ..strokeWidth = 1
          ..color = AppColors.gold.withValues(alpha: 0.6),
      );
    }
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) =>
      other is PeanutLobeBorder &&
      other.position == position &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(position, radius);
}
