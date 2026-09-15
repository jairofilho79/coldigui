import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../theme/gesture_reader_palette.dart';
import 'repeat_block_view.dart';

/// `CORO`: rótulo azul negrito acima, chave **tracejada** à direita dos filhos.
class ChorusBlockView extends StatelessWidget {
  const ChorusBlockView({
    required this.palette,
    required this.children,
    super.key,
  });

  final GestureReaderPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l10n?.gestureContextChorus ?? 'CORO',
            style: TextStyle(
              color: palette.blue,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
        BracedChildren(dashed: true, palette: palette, children: children),
      ],
    );
  }
}
