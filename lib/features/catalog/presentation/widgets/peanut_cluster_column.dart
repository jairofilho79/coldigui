import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Coluna dos gomos do amendoim (spec louvores-agrupados §6.3): empilha os
/// filhos na largura toda, sem espaço, e pinta **uma** sombra da silhueta
/// somada — com as alturas medidas de cada gomo e o mesmo desenho da
/// `PeanutLobeBorder` — antes dos filhos.
///
/// Nem um retângulo arredondado nem a sombra de cada gomo servem: o
/// retângulo mostra uma cunha cinza no bico, e as sombras por gomo sangram
/// no gomo de cima.
class PeanutClusterColumn extends MultiChildRenderObjectWidget {
  const PeanutClusterColumn({
    required super.children,
    this.radius = carouselChipModalRadius,
    this.shadows = AppColors.shadowMd,
    super.key,
  });

  final double radius;
  final List<BoxShadow> shadows;

  @override
  RenderPeanutClusterColumn createRenderObject(BuildContext context) =>
      RenderPeanutClusterColumn(radius: radius, shadows: shadows);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPeanutClusterColumn renderObject,
  ) {
    renderObject
      ..radius = radius
      ..shadows = shadows;
  }
}

class _PeanutClusterParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPeanutClusterColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PeanutClusterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PeanutClusterParentData> {
  RenderPeanutClusterColumn({
    required double radius,
    required List<BoxShadow> shadows,
  }) : _radius = radius, // ignore: prefer_initializing_formals
       _shadows = shadows; // ignore: prefer_initializing_formals

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> value) {
    if (listEquals(value, _shadows)) return;
    _shadows = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PeanutClusterParentData) {
      child.parentData = _PeanutClusterParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints.tightFor(width: width);
    var y = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final parentData = child.parentData! as _PeanutClusterParentData;
      parentData.offset = Offset(0, y);
      y += child.size.height;
      child = parentData.nextSibling;
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (childCount >= 2 && _shadows.isNotEmpty) {
      final silhouette = Path();
      var index = 0;
      var child = firstChild;
      while (child != null) {
        final parentData = child.parentData! as _PeanutClusterParentData;
        silhouette.addPath(
          peanutLobePath(
            (offset + parentData.offset) & child.size,
            lobePositionAt(index, childCount),
            radius: _radius,
          ),
          Offset.zero,
        );
        index++;
        child = parentData.nextSibling;
      }
      for (final shadow in _shadows) {
        context.canvas.drawPath(
          silhouette.shift(shadow.offset),
          shadow.toPaint(),
        );
      }
    }
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
