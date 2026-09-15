import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';

/// Rótulo l10n de uma instrução.
String instructionLabel(AppLocalizations l10n, InstructionKind kind) => switch (kind) {
  InstructionKind.instruments => l10n.gestureInstructionInstruments,
  InstructionKind.repeatPraise => l10n.gestureInstructionRepeatPraise,
  InstructionKind.backToChorus => l10n.gestureInstructionBackToChorus,
  InstructionKind.backToChorusAndFinish => l10n.gestureInstructionBackToChorusAndFinish,
};

/// Cartão de largura total com a instrução (`Instrumentos`, `Voltar ao coro`…).
class InstructionCardView extends StatelessWidget {
  const InstructionCardView({required this.kind, required this.palette, super.key});

  final InstructionKind kind;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.instructionBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.instructionBorder),
      ),
      child: Text(
        instructionLabel(l10n, kind),
        style: TextStyle(color: palette.instructionText, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
