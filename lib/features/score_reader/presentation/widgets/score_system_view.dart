import 'dart:math' as math;

import 'package:crisp_notation/crisp_notation.dart'
    hide Interval, Key, PageMetrics;
// O pintor de primitivas do crisp: o mesmo traço dos widgets do pacote, mas
// aqui aplicado a um sistema por vez (o `MultiPartView` repinta a página
// inteira a cada nota destacada).
// ignore: implementation_imports
import 'package:crisp_notation/src/rendering/layout_painter.dart';
import 'package:flutter/material.dart' hide Interval;

import '../utils/score_systems_layout.dart';

/// Um sistema (linha) da partitura, desenhado com o [painter] compartilhado.
///
/// [highlightedIds] já vem filtrado para este sistema: os que não mudaram
/// não repintam. [loopMeasures] sombreia o trecho do loop A-B.
class ScoreSystemView extends StatelessWidget {
  const ScoreSystemView({
    required this.system,
    required this.painter,
    required this.staffSpace,
    this.highlightedIds = const {},
    this.loopMeasures,
    this.loopColor,
    this.onElementTap,
    this.onMeasureLongPress,
    super.key,
  });

  final StaffSystemSystem system;
  final LayoutPainter painter;
  final double staffSpace;
  final Set<String> highlightedIds;
  final ({int first, int last})? loopMeasures;
  final Color? loopColor;
  final ValueChanged<String>? onElementTap;
  final ValueChanged<int>? onMeasureLongPress;

  double get _height =>
      (system.layout.height + 2 * kScoreSystemPadding) * staffSpace;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size(double.infinity, _height),
      painter: _SystemPainter(
        system: system,
        painter: painter,
        staffSpace: staffSpace,
        highlightedIds: highlightedIds,
        loopMeasures: loopMeasures,
        loopColor: loopColor ?? painter.theme.highlightColor,
      ),
    );
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onElementTap == null
            ? null
            : (details) {
                final id = _elementAt(details.localPosition);
                if (id != null) onElementTap!(id);
              },
        onLongPressStart: onMeasureLongPress == null
            ? null
            : (details) {
                final m = _measureAt(details.localPosition.dx);
                if (m != null) onMeasureLongPress!(m);
              },
        child: paint,
      ),
    );
  }

  double get _originX => kScoreSystemMarginLeft * staffSpace;
  double get _topY => (kScoreSystemPadding - system.layout.top) * staffSpace;

  /// Mesma regra do crisp: a menor região (inflada pelo `hitSlop`) que contém
  /// o ponto.
  String? _elementAt(Offset local) {
    final slop = painter.theme.hitSlop;
    final layout = system.layout;
    String? best;
    var bestArea = double.infinity;
    for (var i = 0; i < layout.staves.length; i++) {
      final partY = _topY + layout.staffTop(i) * staffSpace;
      final point = math.Point(
        (local.dx - _originX) / staffSpace,
        (local.dy - partY) / staffSpace,
      );
      for (final region in layout.staves[i].regions) {
        final b = region.bounds;
        final inflated = math.Rectangle(
          b.left - slop,
          b.top - slop,
          b.width + 2 * slop,
          b.height + 2 * slop,
        );
        if (!inflated.containsPoint(point)) continue;
        final area = inflated.width * inflated.height;
        if (area < bestArea) {
          bestArea = area;
          best = region.elementId;
        }
      }
    }
    return best;
  }

  int? _measureAt(double dx) {
    final x = (dx - _originX) / staffSpace;
    for (final m in system.layout.staves.first.measureRegions) {
      if (x >= m.startX && x < m.endX) return system.firstMeasure + m.index;
    }
    return null;
  }
}

class _SystemPainter extends CustomPainter {
  _SystemPainter({
    required this.system,
    required this.painter,
    required this.staffSpace,
    required this.highlightedIds,
    required this.loopMeasures,
    required this.loopColor,
  });

  final StaffSystemSystem system;
  final LayoutPainter painter;
  final double staffSpace;
  final Set<String> highlightedIds;
  final ({int first, int last})? loopMeasures;
  final Color loopColor;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = system.layout;
    final s = staffSpace;
    final originX = kScoreSystemMarginLeft * s;
    final topY = (kScoreSystemPadding - layout.top) * s;
    double partY(int i) => topY + layout.staffTop(i) * s;

    _paintLoop(canvas, originX, partY(0), partY(layout.staves.length - 1));

    painter
      ..scale = s
      ..highlightedIds = highlightedIds;
    for (var i = 0; i < layout.staves.length; i++) {
      painter.paintLayout(canvas, Offset(originX, partY(i)), layout.staves[i]);
    }
    painter.highlightedIds = const {};
    _paintBarlineGroups(canvas, originX, topY);
    _paintBrackets(canvas, originX, partY);
    _paintMeasureNumber(canvas, originX, partY(0));
  }

  void _paintLoop(Canvas canvas, double originX, double top, double last) {
    final loop = loopMeasures;
    if (loop == null) return;
    if (loop.last < system.firstMeasure || loop.first > system.lastMeasure) {
      return;
    }
    final paint = Paint()..color = loopColor.withValues(alpha: 0.12);
    for (final m in system.layout.staves.first.measureRegions) {
      final global = system.firstMeasure + m.index;
      if (global < loop.first || global > loop.last) continue;
      canvas.drawRect(
        Rect.fromLTRB(
          originX + m.startX * staffSpace,
          top - staffSpace,
          originX + m.endX * staffSpace,
          last + 5 * staffSpace,
        ),
        paint,
      );
    }
  }

  // Barras que atravessam o grupo de pautas — porta do `MultiPartView`.
  void _paintBarlineGroups(Canvas canvas, double originX, double topY) {
    final layout = system.layout;
    if (layout.staves.length < 2) return;
    final barPaint = Paint()..color = painter.theme.staffColor;
    final ref = layout.staves.first.primitives.whereType<LinePrimitive>();
    final startThickness = ref.isEmpty ? 0.13 : ref.first.thickness;
    final bars = <({double x, double thickness})>[
      (x: 0.0, thickness: startThickness),
      for (final line in ref)
        if (line.from.x == line.to.x &&
            ((line.from.y == 0 && line.to.y == 4) ||
                (line.from.y == 4 && line.to.y == 0)))
          (x: line.from.x, thickness: line.thickness),
    ];
    for (final span in layout.barlineSpans) {
      final top = topY + span.top * staffSpace;
      final bottom = topY + span.bottom * staffSpace;
      for (final bar in bars) {
        final x = originX + bar.x * staffSpace;
        canvas.drawLine(
          Offset(x, top),
          Offset(x, bottom),
          barPaint..strokeWidth = bar.thickness * staffSpace,
        );
      }
    }
  }

  int _depthOf(List<StaffBracket> all, StaffBracket b) => all
      .where(
        (a) =>
            !identical(a, b) &&
            a.first <= b.first &&
            b.last <= a.last &&
            (a.last - a.first) > (b.last - b.first),
      )
      .length;

  void _paintBrackets(
    Canvas canvas,
    double originX,
    double Function(int) partY,
  ) {
    final layout = system.layout;
    final brackets = layout.source.brackets;
    if (brackets.isEmpty) return;
    const step = 0.6;
    final maxDepth = brackets
        .map((b) => _depthOf(brackets, b))
        .fold(0, math.max);
    final color = painter.theme.staffColor;
    for (final group in brackets) {
      final shift = (maxDepth - _depthOf(brackets, group)) * step * staffSpace;
      final top = partY(group.first);
      final bottom = partY(group.last) + 4 * staffSpace;
      if (group.kind == StaffBracketKind.brace) {
        final box = MusicFonts.metadataOrNull(painter.theme.musicFont)
            ?.bBoxOf('brace');
        if (box == null) continue;
        final span =
            layout.staffTop(group.last) + 4 - layout.staffTop(group.first);
        painter.paintGlyph(
          canvas,
          Offset(originX - shift, partY(group.last)),
          'brace',
          math.Point(-RenderMultiPartView.leftInset + 0.35, 4.0),
          color,
          glyphScale: span / box.height,
        );
      } else {
        final bx = originX - 0.5 * staffSpace - shift;
        final paint = Paint()
          ..color = color
          ..strokeWidth = 0.4 * staffSpace;
        canvas.drawLine(Offset(bx, top), Offset(bx, bottom), paint);
        final serif = Paint()
          ..color = color
          ..strokeWidth = 0.16 * staffSpace;
        canvas
          ..drawLine(Offset(bx, top), Offset(bx + 0.6 * staffSpace, top), serif)
          ..drawLine(
            Offset(bx, bottom),
            Offset(bx + 0.6 * staffSpace, bottom),
            serif,
          );
      }
    }
  }

  void _paintMeasureNumber(Canvas canvas, double originX, double topStaffY) {
    if (system.firstMeasure == 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: '${system.firstMeasure + 1}',
        style: TextStyle(
          color: painter.theme.staffColor,
          fontSize: 1.1 * staffSpace,
          fontFamily: painter.theme.textFontFamily,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(originX, topStaffY - 2.6 * staffSpace));
  }

  @override
  bool shouldRepaint(_SystemPainter old) =>
      !identical(old.system, system) ||
      !identical(old.painter, painter) ||
      old.staffSpace != staffSpace ||
      old.loopMeasures != loopMeasures ||
      old.loopColor != loopColor ||
      !_sameIds(old.highlightedIds, highlightedIds);

  static bool _sameIds(Set<String> a, Set<String> b) =>
      identical(a, b) || (a.length == b.length && a.containsAll(b));
}
