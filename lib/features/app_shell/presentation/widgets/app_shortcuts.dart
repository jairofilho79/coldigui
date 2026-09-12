import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
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

/// `true` quando o foco está num controle para o qual `Espaço` já tem dono.
///
/// O `Shortcuts` de [WidgetsApp] liga `Espaço` a `ActivateIntent` (na web
/// `PrioritizedIntents([Activate, Scroll])`) e mora **acima** do
/// `MaterialApp.router` — ou seja, acima de [AppShortcuts]. Como o evento sobe
/// do nó com foco para os ancestrais, [AppShortcuts] vê a tecla **antes** e, se
/// a consumir, o intent nunca dispara: com uma faixa carregada, `Espaço` num
/// botão da barra, num destino da navegação ou num card viraria play/pause em
/// vez de acionar o controle, e deixaria de rolar a cifra.
///
/// Então o play/pause por `Espaço` só vale quando nada com semântica própria
/// está focado: sem foco, num `FocusScopeNode` (foco "de tela", não de widget)
/// ou num nó que não está dentro de um [InkResponse] / [ButtonStyleButton] /
/// [Scrollable].
bool keyboardFocusIsOnSpaceActivatableControl() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || focus is FocusScopeNode) return false;

  final context = focus.context;
  if (context == null) return false;

  bool ownsSpace(Widget widget) =>
      widget is InkResponse ||
      widget is ButtonStyleButton ||
      widget is Scrollable;

  if (ownsSpace(context.widget)) return true;

  var found = false;
  context.visitAncestorElements((element) {
    if (ownsSpace(element.widget)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Troca de louvor pelo teclado dentro do leitor (PDF ou cifra).
///
/// Percorre o mesmo caminho das setas da barra 2: posição na face de
/// partituras -> [ReaderCarouselActionsNotifier.navigateToKey] -> `replace` da
/// rota. Fica aqui, e não em cada leitor, porque `N`/`P` e `Ctrl+→` têm que se
/// comportar igual nos dois — e o leitor de cifras não pode importar o widget
/// do leitor de PDF.
///
/// A navegação é **por chave**: com o mesmo louvor repetido na lista, o
/// vizinho do id é ambíguo, o da ocorrência não.
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

  final targetKey = switch (direction) {
    CarouselReaderDirection.previous => position.previousKey,
    CarouselReaderDirection.next => position.nextKey,
  };
  if (targetKey == null) return false;

  try {
    // `navigateToKey` foca a ocorrência antes de resolver a rota.
    final location = await ref
        .read(readerCarouselActionsProvider.notifier)
        .navigateToKey(key: targetKey);
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
/// | `J` / `L` | ±10 s no áudio (mesma guarda de foco do Espaço) — C12 |
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

  /// `true` quando há um sheet/diálogo aberto por cima — ele é o dono do `Esc`.
  ///
  /// Nenhum `showModalBottomSheet` do app pede `useRootNavigator`, então o
  /// sheet sobe ora no Navigator raiz (acima daqui — a rota desta subárvore
  /// deixa de ser a corrente), ora no Navigator aninhado do shell (dentro
  /// desta subárvore, onde a tecla chega até os atalhos: aí o que denuncia o
  /// modal é a rota que contém o foco ser um [PopupRoute]).
  static bool _modalIsOpenAbove(BuildContext context) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return true;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return ModalRoute.of(focused) is PopupRoute;
  }

  bool _playPause(WidgetRef ref) {
    final session = ref.read(audioPlayerSessionProvider);
    if (session.currentTrack == null) return false;
    ref.read(audioPlayerSessionProvider.notifier).playPause();
    return true;
  }

  /// `J`/`L` (C12): ±10 s no áudio em foco.
  bool _seekBy(WidgetRef ref, Duration delta) {
    final session = ref.read(audioPlayerSessionProvider);
    if (session.currentTrack == null) return false;
    ref.read(audioPlayerSessionProvider.notifier).seekBy(delta);
    return true;
  }

  KeyEventResult _onKeyEvent(BuildContext context, WidgetRef ref, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;

    final key = e.logicalKey;
    final pressed = HardwareKeyboard.instance;
    final commandModifier = pressed.isControlPressed || pressed.isMetaPressed;

    // Escape sai da tela cheia mesmo com foco em campo de texto: é a saída de
    // emergência do modo imersivo. Mas um sheet/diálogo aberto por cima é o
    // dono legítimo do Esc — os sheets do app sobem no Navigator aninhado do
    // shell, ou seja dentro desta subárvore, e a tecla chegaria aqui.
    if (key == LogicalKeyboardKey.escape) {
      if (_modalIsOpenAbove(context) || !_isReaderRoute) {
        return KeyEventResult.ignored;
      }
      if (!ref.read(readerFullscreenProvider)) {
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
      // `Espaço` é a tecla de "ativar" e de rolar do Flutter: só vira
      // play/pause quando não há controle nenhum com direito sobre ela.
      if (keyboardFocusIsOnSpaceActivatableControl()) {
        return KeyEventResult.ignored;
      }
      return _playPause(ref) ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.keyL) {
      // Mesmo padrão do F: um atalho do navegador/SO com o mesmo
      // modificador (ex.: Ctrl+J abre downloads em vários navegadores) tem
      // prioridade — sem isto o seek disparava junto.
      if (commandModifier) return KeyEventResult.ignored;
      // Mesma guarda do Espaço: um botão/campo com foco tem prioridade.
      if (keyboardFocusIsOnSpaceActivatableControl()) {
        return KeyEventResult.ignored;
      }
      final delta = key == LogicalKeyboardKey.keyJ
          ? const Duration(seconds: -10)
          : const Duration(seconds: 10);
      return _seekBy(ref, delta)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
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
