import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/gesture_providers.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../../domain/entities/gesture_reader_font_size.dart';
import '../providers/gesture_reader_font_size_provider.dart';
import '../widgets/gesture_document_view.dart';
import '../widgets/newer_schema_banner.dart';

const Key gestureReaderRetryKey = ValueKey('gesture-reader-retry');

/// Leitor de gestos CIAs — rota `/gestos`, filha do [ShellScaffold].
///
/// Espelho de `ChordReaderScreen`: barras 1–2 vêm do shell; aqui ficam a barra
/// 3 (`A-`/`A+`, tela cheia) e o papel. Recebe [UrlSyncParams.pdfId] (id do
/// material, mesmo espaço do PDF), `titulo` e `subtitulo`; publica os params
/// em [readerRouteParamsProvider] para o [CarouselChips] sincronizar o chip.
class GestureReaderScreen extends ConsumerStatefulWidget {
  const GestureReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<GestureReaderScreen> createState() => _GestureReaderScreenState();
}

class _GestureReaderScreenState extends ConsumerState<GestureReaderScreen> {
  late final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'gestureReaderKeys');
  final _documentViewKey = GlobalKey<GestureDocumentViewState>();
  var _louvorNavigationInProgress = false;
  var _prefetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// `r2Key` decodificado do id da rota; vazio se o id faltar ou for inválido.
  String get _r2Key {
    final id = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (id.isEmpty) return '';
    try {
      return PdfPathNormalizer.getPdfRelPath(id);
    } on Object {
      return '';
    }
  }

  Future<void> _navigateLouvor(CarouselReaderDirection direction) async {
    if (_louvorNavigationInProgress) return;
    _louvorNavigationInProgress = true;
    try {
      await navigateReaderCarouselByKeyboard(
        ref: ref,
        context: context,
        currentPdfId: widget.queryParams[UrlSyncParams.pdfId],
        direction: direction,
      );
    } finally {
      _louvorNavigationInProgress = false;
    }
  }

  /// `Ctrl+↑/↓` corpo da letra, `Ctrl+←/→` troca de louvor. `F`/`Esc` sobem
  /// para [AppShortcuts]. As setas sem modificador ficam para o modo foco.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      ref.read(gestureReaderFontSizeProvider.notifier).increase();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      ref.read(gestureReaderFontSizeProvider.notifier).decrease();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _navigateLouvor(CarouselReaderDirection.next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _navigateLouvor(CarouselReaderDirection.previous);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Aquece as figuras uma vez por documento+dicionário carregados.
  void _maybePrefetch(GestureDocument document, GestureDictionary dictionary) {
    if (_prefetched) return;
    _prefetched = true;
    prefetchGestureFigures(
      ref.read(gestureFigureRepositoryProvider),
      document,
      dictionary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = ref.watch(gestureReaderFontSizeProvider);
    final docAsync = ref.watch(gestureDocumentProvider(_r2Key));
    final dictionary =
        ref.watch(gestureDictionaryProvider).asData?.value ?? GestureDictionary.empty;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: (_) => _keyboardFocusNode.requestFocus(),
        // `Material` com `transparency`: o cartão de gesto e a mensagem de
        // estado usam `InkWell`, que exige um ancestral `Material`. No app o
        // `ShellScaffold` já provê um `Scaffold`, mas isolar a tela de quem a
        // hospeda evita depender disso.
        child: Material(
          type: MaterialType.transparency,
          child: ColoredBox(
            color: AppColors.background,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GestureReaderToolbar(fontSize: fontSize, l10n: l10n),
                  Expanded(
                    child: docAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => _Message(
                        message: l10n.gesturesReaderUnavailable,
                        onTap: () =>
                            ref.invalidate(gestureDocumentProvider(_r2Key)),
                        key: gestureReaderRetryKey,
                      ),
                      data: (document) {
                        if (document == null) {
                          return _Message(message: l10n.gesturesReaderEmpty);
                        }
                        if (dictionary.byId.isNotEmpty) {
                          _maybePrefetch(document, dictionary);
                        }
                        return Column(
                          children: [
                            if (document.isNewerSchema)
                              const NewerSchemaBanner(),
                            Expanded(
                              child: GestureDocumentView(
                                key: _documentViewKey,
                                document: document,
                                dictionary: dictionary,
                                fontSize: fontSize,
                                // Task 15 liga o modo foco aqui.
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.onTap, super.key});

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textLight),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _toolbarButtonStyle(Color color) => IconButton.styleFrom(
  foregroundColor: color,
  disabledForegroundColor: color.withValues(alpha: 0.38),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: const Size(44, 44),
);

/// Barra 3: corpo da letra e tela cheia.
class _GestureReaderToolbar extends ConsumerWidget {
  const _GestureReaderToolbar({required this.fontSize, required this.l10n});

  final double fontSize;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(gestureReaderFontSizeProvider.notifier);
    final style = _toolbarButtonStyle(AppColors.gold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderDecreaseFont,
            icon: const Icon(Icons.text_decrease),
            onPressed: GestureReaderFontSize.canDecrease(fontSize) ? size.decrease : null,
          ),
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderIncreaseFont,
            icon: const Icon(Icons.text_increase),
            onPressed: GestureReaderFontSize.canIncrease(fontSize) ? size.increase : null,
          ),
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderFullscreen,
            icon: const Icon(Icons.fullscreen),
            onPressed: () => ref.read(toggleReaderFullscreenProvider).call(),
          ),
        ],
      ),
    );
  }
}
