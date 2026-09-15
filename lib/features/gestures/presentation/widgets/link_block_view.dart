import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';
import 'link_connector_painter.dart';

/// Ligação: filhos sem espaço entre si + conector laranja à esquerda.
class LinkBlockView extends StatelessWidget {
  const LinkBlockView({required this.palette, required this.children, super.key});

  final GestureReaderPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: kGestureLinkWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: kGestureLinkWidth,
          child: CustomPaint(
            key: gestureLinkConnectorKey,
            painter: LinkConnectorPainter(palette: palette),
          ),
        ),
      ],
    );
  }
}
