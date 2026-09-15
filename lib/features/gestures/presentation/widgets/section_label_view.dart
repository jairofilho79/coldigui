import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';

/// Rótulo discreto da leitura linear («CORO», «2ª VEZ»): diz onde a regente
/// está na música sem virar marcação de salto — por isso é pequeno, cinza e
/// sem chave.
class SectionLabelView extends StatelessWidget {
  const SectionLabelView({
    required this.label,
    required this.fontSize,
    required this.palette,
    super.key,
  });

  final SectionLabel label;
  final double fontSize;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pass = label.pass;
    final text = pass == null ? l10n.gestureSectionChorus : l10n.gestureSectionPass(pass);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: palette.sectionLabel,
          fontSize: fontSize * 0.7,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
