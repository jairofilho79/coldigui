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
    this.preferGif = false,
    super.key,
  });

  final GestureEntry? entry;
  final String gestureId;
  final double side;
  final bool preferGif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = this.entry;
    if (entry == null) return _Placeholder(gestureId: gestureId, side: side);

    final key = preferGif ? (entry.gif ?? entry.image) : entry.image;
    final bytes = ref.watch(gestureFigureProvider(key));

    return SizedBox(
      width: side,
      height: side,
      child: ColoredBox(
        color: GestureReaderPalette.paper,
        child: bytes.when(
          loading: () => const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => _Placeholder(gestureId: gestureId, side: side),
          data: (data) => data == null
              ? _Placeholder(gestureId: gestureId, side: side)
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
  const _Placeholder({required this.gestureId, required this.side});

  final String gestureId;
  final double side;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: gesturePlaceholderKey(gestureId),
      width: side,
      height: side,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: GestureReaderPalette.placeholderBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GestureReaderPalette.placeholderBorder, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pan_tool_outlined, size: 20, color: GestureReaderPalette.placeholderBorder),
          const SizedBox(height: 4),
          Text(
            l10n?.gestureNotFound ?? 'gesto não encontrado',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: GestureReaderPalette.freeText),
          ),
          Text(
            gestureId,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: GestureReaderPalette.freeText),
          ),
        ],
      ),
    );
  }
}
