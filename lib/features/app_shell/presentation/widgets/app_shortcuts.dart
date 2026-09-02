import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';

/// Pedido de foco no campo de busca da Home (C1).
///
/// Contador em vez de `bool`: dois `Ctrl+K` seguidos precisam focar duas vezes,
/// e um estado booleano só notificaria na primeira. Quem escuta é a
/// [HomeScreen], dona do [FocusNode] da barra de busca.
class SearchFocusRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final searchFocusRequestProvider =
    NotifierProvider<SearchFocusRequestNotifier, int>(
      SearchFocusRequestNotifier.new,
    );

/// `true` quando o foco está dentro de um campo de texto.
///
/// Atalhos de tecla seca (`/`, `Espaço`, `F`) não podem disparar enquanto o
/// usuário digita — `/` numa busca é uma barra, não um atalho. O nó com foco é
/// o `Focus` interno do [EditableText], então a checagem sobe um nível.
bool keyboardFocusIsInsideTextField() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Troca de louvor pelo teclado dentro do leitor (PDF ou cifra).
///
/// Percorre o mesmo caminho das setas da barra 2: posição no carousel ->
/// [ReaderCarouselActionsNotifier.navigateToPdfId] -> `replace` da rota. Fica
/// aqui, e não em cada leitor, porque `Ctrl+→` tem que se comportar igual nos
/// dois — e o leitor de cifras não pode importar o widget do leitor de PDF.
///
/// Retorna `false` quando não há vizinho naquela direção.
Future<bool> navigateReaderCarouselByKeyboard({
  required WidgetRef ref,
  required BuildContext context,
  required String? currentPdfId,
  required CarouselReaderDirection direction,
}) async {
  if (currentPdfId == null || currentPdfId.isEmpty) return false;

  final position = ref.read(readerCarouselPositionProvider(currentPdfId));
  if (position == null) return false;

  final targetPdfId = switch (direction) {
    CarouselReaderDirection.previous => position.previousPdfId,
    CarouselReaderDirection.next => position.nextPdfId,
  };
  if (targetPdfId == null) return false;

  ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(targetPdfId);

  try {
    final location = await ref
        .read(readerCarouselActionsProvider.notifier)
        .navigateToPdfId(targetPdfId: targetPdfId);
    if (!context.mounted) return false;

    if (location == null) {
      _showReaderActionError(context);
      return false;
    }
    context.replace(location);
    return true;
  } on Object catch (error) {
    debugPrint('[AppShortcuts.navigateReaderCarouselByKeyboard] $error');
    if (context.mounted) _showReaderActionError(context);
    return false;
  }
}

void _showReaderActionError(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showAppSnackbar(
    context,
    l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
  );
}

/// Atalhos globais de teclado (C1) — envolve o `Scaffold` do [ShellScaffold].
///
/// Fica **acima** de toda a árvore de rotas de propósito: o evento nasce no nó
/// com foco (por exemplo o handler de páginas do leitor PDF) e só sobe até aqui
/// se ninguém o consumiu. É assim que `Espaço` vira página dentro do leitor e
/// play/pause em qualquer outro lugar.
///
/// | Tecla | Efeito |
/// | --- | --- |
/// | `Ctrl+K` / `Cmd+K` / `/` | vai para a Home e foca a busca |
/// | `Espaço` | play/pause (fora do leitor PDF, que consome a tecla) |
/// | `Ctrl+Espaço` / `Cmd+Espaço` | play/pause também dentro do leitor |
/// | `F` | tela cheia no leitor PDF e no leitor de cifras |
/// | `Esc` | sai da tela cheia |
class AppShortcuts extends ConsumerWidget {
  const AppShortcuts({required this.path, required this.child, super.key});

  /// Caminho da rota atual do shell — decide `F`/`Esc`.
  final String path;

  final Widget child;

  bool get _isReaderRoute =>
      path == RoutePaths.reader || path == RoutePaths.chords;

  void _focusSearch(BuildContext context, WidgetRef ref) {
    goToShellDestination(context, RoutePaths.home);
    // A Home pode estar sendo montada agora (vinda do leitor); pedir o foco no
    // mesmo frame chegaria antes do `ref.listen` dela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchFocusRequestProvider.notifier).request();
    });
  }

  bool _playPause(WidgetRef ref) {
    final session = ref.read(audioPlayerSessionProvider);
    if (session.currentTrack == null) return false;
    ref.read(audioPlayerSessionProvider.notifier).playPause();
    return true;
  }

  KeyEventResult _onKeyEvent(BuildContext context, WidgetRef ref, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;

    final key = e.logicalKey;
    final pressed = HardwareKeyboard.instance;
    final commandModifier = pressed.isControlPressed || pressed.isMetaPressed;

    // Escape sai da tela cheia mesmo com foco em campo de texto: é a saída de
    // emergência do modo imersivo.
    if (key == LogicalKeyboardKey.escape) {
      if (!_isReaderRoute || !ref.read(readerFullscreenProvider)) {
        return KeyEventResult.ignored;
      }
      ref.read(readerFullscreenProvider.notifier).exit();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyK && commandModifier) {
      _focusSearch(context, ref);
      return KeyEventResult.handled;
    }

    if (keyboardFocusIsInsideTextField()) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide) {
      if (commandModifier) return KeyEventResult.ignored;
      _focusSearch(context, ref);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space) {
      return _playPause(ref) ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.keyF) {
      if (commandModifier || !_isReaderRoute) return KeyEventResult.ignored;
      ref.read(toggleReaderFullscreenProvider).call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKeyEvent(context, ref, event),
      child: child,
    );
  }
}
