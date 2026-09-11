import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../../features/pdf_reader/presentation/providers/reader_side_panel_provider.dart';
import '../../layout/breakpoints.dart';

/// Split view do leitor de PDF e da cifra (spec A.6 C7).
///
/// Em tela larga ([isWideLayout]), fora de fullscreen
/// ([readerFullscreenProvider]) e com [readerSidePanelOpenProvider] ligado,
/// mostra [panel] à direita de [child] com [panelWidth] fixos. Fora dessas
/// condições, devolve só [child] — o botão `Icons.view_sidebar` nas barras
/// do leitor de PDF e da cifra alterna [readerSidePanelOpenProvider].
class ReaderSplitLayout extends ConsumerWidget {
  const ReaderSplitLayout({
    required this.child,
    required this.panel,
    this.panelWidth = 320,
    super.key,
  });

  /// Área principal — documento PDF ou corpo da cifra.
  final Widget child;

  /// Painel lateral — tipicamente [ActiveListPanel].
  final Widget panel;

  /// Largura fixa do painel quando visível.
  final double panelWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFullscreen = ref.watch(readerFullscreenProvider);
    final panelOpen = ref.watch(readerSidePanelOpenProvider);
    final showPanel = !isFullscreen && panelOpen && isWideLayout(context);

    if (!showPanel) return child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        SizedBox(width: panelWidth, child: panel),
      ],
    );
  }
}
