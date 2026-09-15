import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/providers/gesture_providers.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../theme/gesture_reader_palette.dart';

/// Chave do placeholder de gesto ausente — para testes e para achar na tela.
Key gesturePlaceholderKey(String gestureId) => ValueKey('gesture-placeholder-$gestureId');

/// Figura do gesto num quadrado de [side], fundo branco, `BoxFit.contain`.
///
/// [entry] `null` (id fora do dicionário) ou bytes `null` (download falhou)
/// viram o placeholder tracejado com o id em fonte pequena — nunca erro.
/// [preferGif] só no modo foco: mostra o GIF quando a entrada tem um.
class GestureFigure extends ConsumerWidget {
  const GestureFigure({
    required this.entry,
    required this.gestureId,
    required this.side,
    required this.palette,
    this.preferGif = false,
    super.key,
  });

  final GestureEntry? entry;
  final String gestureId;
  final double side;
  final GestureReaderPalette palette;
  final bool preferGif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = this.entry;
    if (entry == null) return _Placeholder(gestureId: gestureId, side: side, palette: palette);

    final key = preferGif ? (entry.gif ?? entry.image) : entry.image;
    final bytes = ref.watch(gestureFigureProvider(key));

    return SizedBox(
      width: side,
      height: side,
      child: ColoredBox(
        color: palette.figureBg,
        child: bytes.when(
          loading: () => const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => _Placeholder(gestureId: gestureId, side: side, palette: palette),
          data: (data) => data == null
              ? _Placeholder(gestureId: gestureId, side: side, palette: palette)
              : Image.memory(
                  data,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.gestureId, required this.side, required this.palette});

  final String gestureId;
  final double side;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: gesturePlaceholderKey(gestureId),
      width: side,
      height: side,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.placeholderBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.placeholderBorder, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pan_tool_outlined, size: 20, color: palette.placeholderBorder),
          const SizedBox(height: 4),
          Text(
            l10n?.gestureNotFound ?? 'gesto não encontrado',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: palette.sectionLabel),
          ),
          Text(
            gestureId,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: palette.sectionLabel),
          ),
        ],
      ),
    );
  }
}
