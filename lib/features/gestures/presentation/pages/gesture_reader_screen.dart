import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../autoscroll/domain/entities/autoscroll_adjustment.dart';
import '../../../autoscroll/presentation/providers/autoscroll_telemetry_providers.dart';
import '../../../autoscroll/presentation/widgets/autoscroll_speed_slider_bar.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../../contributions/domain/entities/contribution_kind.dart';
import '../../../contributions/domain/entities/contribution_target.dart';
import '../../../contributions/presentation/utils/open_contribute.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/gesture_providers.dart';
import '../../domain/entities/flat_gesture_card.dart';
import '../../domain/entities/gesture_autoscroll_speed.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../../domain/entities/gesture_reader_font_size.dart';
import '../../domain/usecases/linearize_gesture_document.dart';
import '../../domain/utils/flatten_gesture_cards.dart';
import '../providers/gesture_autoscroll_provider.dart';
import '../providers/gesture_reader_font_size_provider.dart';
import '../providers/gesture_reader_linear_provider.dart';
import '../providers/gesture_reader_mode_provider.dart';
import '../theme/gesture_reader_palette.dart';
import '../theme/gesture_reader_theme.dart';
import '../widgets/gesture_document_view.dart';
import '../widgets/gesture_focus_view.dart';
import '../widgets/newer_schema_banner.dart';

const Key gestureReaderRetryKey = ValueKey('gesture-reader-retry');
const Key gestureReaderThemeKey = ValueKey('gesture-reader-theme');
const Key gestureReaderLinearKey = ValueKey('gesture-reader-linear');
const Key gestureReaderAutoscrollKey = ValueKey('gesture-reader-autoscroll');
const Key gestureReaderSpeedKey = ValueKey('gesture-reader-speed');
const Key gestureReaderFullscreenKey = ValueKey('gesture-reader-fullscreen');

/// Quanto esperar depois que o dedo solta a página antes de voltar a rolar.
const Duration kGestureAutoscrollResumeDelay = Duration(seconds: 1);

const _toolbarGroupGap = 8.0;
const _speedLabelWidth = 34.0;

/// Leitor de gestos CIAs — rota `/gestos`, filha do [ShellScaffold].
///
/// Espelho de `ChordReaderScreen`: barras 1–2 vêm do shell; aqui ficam a barra
/// 3 (`A-`/`A+`, autoscroll, linear/estruturado, tema e tela cheia) e o papel.
/// Recebe [UrlSyncParams.pdfId] (id do material, mesmo espaço do PDF),
/// `titulo` e `subtitulo`; publica os params em [readerRouteParamsProvider]
/// para o [CarouselChips] sincronizar o chip.
class GestureReaderScreen extends ConsumerStatefulWidget {
  const GestureReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<GestureReaderScreen> createState() =>
      _GestureReaderScreenState();
}

class _GestureReaderScreenState extends ConsumerState<GestureReaderScreen>
    with SingleTickerProviderStateMixin {
  late final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'gestureReaderKeys',
  );
  final _documentViewKey = GlobalKey<GestureDocumentViewState>();
  final ScrollController _scrollController = ScrollController();
  var _louvorNavigationInProgress = false;
  var _prefetched = false;

  Ticker? _autoscrollTicker;
  Duration? _autoscrollLastTick;
  var _showSpeedSlider = false;

  String get _currentPraiseId {
    final rawPdfId = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    final fromLookup =
        ref.read(catalogMaterialLookupProvider).gesture(rawPdfId)?.groupId;
    if (fromLookup != null && fromLookup.isNotEmpty) return fromLookup;
    final fromSource = ref
        .read(coldigomCatalogSourceProvider)
        .findGroupForMaterial(rawPdfId)
        ?.groupId;
    if (fromSource != null && fromSource.isNotEmpty) return fromSource;
    return widget.queryParams[UrlSyncParams.praiseId] ?? '';
  }

  void _applySpeedRecommendation() {
    final praiseId = _currentPraiseId;
    if (praiseId.isEmpty) return;
    final fontSize = ref.read(gestureReaderFontSizeProvider);
    final rec = ref
        .read(autoscrollTelemetryDatasourceProvider)
        .getRecommendedSpeed(
          praiseId: praiseId,
          currentFontSize: fontSize,
          materialKind: 'gesture',
        );
    if (rec != null) {
      ref.read(gestureAutoscrollProvider.notifier).setSpeed(rec);
    }
  }

  void _onSpeedChanged(int speed) {
    ref.read(gestureAutoscrollProvider.notifier).setSpeed(speed);
    final praiseId = _currentPraiseId;
    if (praiseId.isNotEmpty) {
      final fontSize = ref.read(gestureReaderFontSizeProvider);
      ref.read(autoscrollTelemetryDatasourceProvider).recordAdjustment(
            AutoscrollAdjustment(
              praiseId: praiseId,
              materialKind: 'gesture',
              speed: speed,
              fontSize: fontSize,
              timestamp: DateTime.now(),
            ),
          );
    }
  }

  /// Rolagem manual em curso (ou dentro do 1 s de espera). O `Ticker`
  /// continua vivo, só deixa de mover a página — assim a retomada parte de
  /// onde o dedo deixou, sem guardar alvo nenhum.
  var _pausedByUser = false;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    clearSnackbarsOnEnter(context);
    _schedulePublishRouteParams();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applySpeedRecommendation();
    });
  }

  /// `context.replace()` do carousel (Ctrl+←/→) reaproveita a key da página:
  /// o go_router troca só os `queryParams` do widget e chama `didUpdateWidget`
  /// em vez de recriar o `State` — sem isto o chip do [readerRouteParamsProvider]
  /// e o prefetch de figuras ficariam presos no primeiro louvor aberto.
  @override
  void didUpdateWidget(GestureReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mapEquals(widget.queryParams, oldWidget.queryParams)) return;
    _schedulePublishRouteParams();
    if (_r2Key != _r2KeyOf(oldWidget.queryParams)) {
      _prefetched = false;
      _stopAutoscroll();
      _showSpeedSlider = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySpeedRecommendation();
      });
    }
  }

  void _schedulePublishRouteParams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _autoscrollTicker?.dispose();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// `r2Key` decodificado do id da rota; vazio se o id faltar ou for inválido.
  String get _r2Key => _r2KeyOf(widget.queryParams);

  static String _r2KeyOf(Map<String, String> queryParams) {
    final id = queryParams[UrlSyncParams.pdfId] ?? '';
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
  /// para [AppShortcuts]. `S` liga/desliga o autoscroll e `[`/`]` regulam sua
  /// velocidade — essas três não valem com o foco num campo de texto. As
  /// setas sem modificador ficam para o modo foco.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
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
    if (!keyboardFocusIsInsideTextField()) {
      if (key == LogicalKeyboardKey.keyS) {
        ref.read(gestureAutoscrollProvider.notifier).toggle();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketRight) {
        final speed = ref.read(gestureAutoscrollProvider).speed;
        _onSpeedChanged(speed + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketLeft) {
        final speed = ref.read(gestureAutoscrollProvider).speed;
        _onSpeedChanged(speed - 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape && _showSpeedSlider) {
        setState(() => _showSpeedSlider = false);
        return KeyEventResult.handled;
      }
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

  /// Abre o modo foco a partir do cartão [index] e, ao fechar, rola a página
  /// de volta até onde o regente estava.
  Future<void> _openFocus(
    List<FlatGestureCard> cards,
    GestureDictionary dictionary,
    int index,
    double fontSize,
    GestureReaderPalette palette,
  ) async {
    // O foco é paginado — não há o que rolar automaticamente. Sem isto o
    // motor continuaria rolando a página escondida atrás do overlay, e o
    // próximo tick daria um `jumpTo` bem na hora do `scrollToCard` abaixo,
    // cortando os 250 ms de animação antes de chegar no cartão. O botão
    // voltar a ▶ é o estado honesto: o autoscroll não está mais rolando.
    ref.read(gestureAutoscrollProvider.notifier).stop();
    final result = await showGestureFocus(
      context,
      cards: cards,
      dictionary: dictionary,
      initialIndex: index,
      fontSize: fontSize,
      palette: palette,
    );
    if (!mounted || result == null) return;
    await _documentViewKey.currentState?.scrollToCard(result);
    _keyboardFocusNode.requestFocus();
  }

  /// `Ticker`, não `Timer`: sincroniza com o vsync e morre com o `State`.
  void _ensureAutoscrollTicker() {
    _autoscrollTicker ??= createTicker(_onAutoscrollTick);
    if (!_autoscrollTicker!.isActive) {
      _autoscrollLastTick = null;
      _autoscrollTicker!.start();
    }
  }

  void _onAutoscrollTick(Duration elapsed) {
    final lastTick = _autoscrollLastTick;
    _autoscrollLastTick = elapsed;
    if (lastTick == null) return; // primeiro tick só marca o relógio.

    final state = ref.read(gestureAutoscrollProvider);
    if (!state.running) {
      _autoscrollTicker?.stop();
      return;
    }
    if (_pausedByUser || !_scrollController.hasClients) return;

    final dtSeconds =
        (elapsed - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    if (dtSeconds <= 0) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      ref.read(gestureAutoscrollProvider.notifier).stop();
      return;
    }
    final delta =
        state.speed * GestureAutoscrollSpeed.pxPerSecondPerLevel * dtSeconds;
    final next = (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(next);
    if (next >= position.maxScrollExtent) {
      ref.read(gestureAutoscrollProvider.notifier).stop();
    }
  }

  /// Troca de louvor: o motor para na hora, o provider no próximo frame
  /// (Riverpod proíbe escrever provider dentro de `didUpdateWidget`).
  void _stopAutoscroll() {
    _autoscrollTicker?.stop();
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _pausedByUser = false;
    if (!ref.read(gestureAutoscrollProvider).running) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gestureAutoscrollProvider.notifier).stop();
    });
  }

  /// Dedo/roda na página: pausa; 1 s depois do fim do gesto, volta de onde
  /// a página ficou. Dois sinais dizem "é o usuário":
  /// `ScrollStartNotification.dragDetails != null`, disparado dentro de
  /// `position.drag(...)` assim que o dedo cruza o slop — antes de qualquer
  /// `onUpdate` — e `UserScrollNotification` com direção, para a roda do
  /// mouse (`pointerScroll` não passa por `drag`, não tem `dragDetails`).
  /// Só o `UserScroll` chega tarde demais para o dedo: ele só é emitido no
  /// primeiro `onUpdate`, ~8–16 ms depois do `onStart` na amostra seguinte
  /// do ponteiro. Se um tick do `Ticker` cair nessa janela, o `jumpTo` do
  /// motor passa por `goIdle()` → `beginActivity(Idle)`, que descarta o
  /// `_drag` do `ScrollableState` — todo update seguinte do dedo vira no-op
  /// e a página ignora o toque. O `ScrollStart` com `dragDetails` fecha essa
  /// janela; o `jumpTo` do próprio motor também emite `ScrollStart`, mas com
  /// `dragDetails == null`, então não conta como usuário aqui.
  bool _onScrollNotification(ScrollNotification notification) {
    final fingerDown =
        notification is ScrollStartNotification &&
        notification.dragDetails != null;
    final userDirection =
        notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle;
    if (fingerDown || userDirection) {
      _pausedByUser = true;
      _resumeTimer?.cancel();
      _resumeTimer = null;
    } else if (notification is ScrollEndNotification &&
        _pausedByUser &&
        _resumeTimer == null) {
      _resumeTimer = Timer(kGestureAutoscrollResumeDelay, () {
        _resumeTimer = null;
        if (!mounted) return;
        _pausedByUser = false;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(gestureReaderModeProvider);
    final palette = mode.palette;
    final linear = ref.watch(gestureReaderLinearProvider);
    final autoscroll = ref.watch(gestureAutoscrollProvider);
    final fontSize = ref.watch(gestureReaderFontSizeProvider);
    final docAsync = ref.watch(gestureDocumentProvider(_r2Key));
    final dictionary =
        ref.watch(gestureDictionaryProvider).asData?.value ??
        GestureDictionary.empty;

    // Liga/desliga o motor junto da intenção — o provider só guarda o estado.
    ref.listen<GestureAutoscrollState>(gestureAutoscrollProvider, (
      previous,
      next,
    ) {
      if (next.running) {
        _ensureAutoscrollTicker();
      } else {
        _autoscrollTicker?.stop();
        _resumeTimer?.cancel();
        _resumeTimer = null;
        _pausedByUser = false;
      }
    });

    ref.listen<double>(gestureReaderFontSizeProvider, (previous, next) {
      if (previous == null || previous == next) return;
      final praiseId = _currentPraiseId;
      if (praiseId.isEmpty) return;
      final rec = ref
          .read(autoscrollTelemetryDatasourceProvider)
          .getRecommendedSpeed(
            praiseId: praiseId,
            currentFontSize: next,
            materialKind: 'gesture',
          );
      if (rec != null) {
        ref.read(gestureAutoscrollProvider.notifier).setSpeed(rec);
      }
    });

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
            color: palette.paper,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GestureReaderToolbar(
                    mode: mode,
                    palette: palette,
                    fontSize: fontSize,
                    linear: linear,
                    autoscroll: autoscroll,
                    showSpeedSlider: _showSpeedSlider,
                    onToggleSpeedSlider: () =>
                        setState(() => _showSpeedSlider = !_showSpeedSlider),
                    l10n: l10n,
                    gestureId: widget.queryParams[UrlSyncParams.pdfId] ?? '',
                    praiseId: _currentPraiseId,
                  ),
                  if (_showSpeedSlider)
                    AutoscrollSpeedSliderBar(
                      speed: autoscroll.speed,
                      onSpeedChanged: _onSpeedChanged,
                      onClose: () => setState(() => _showSpeedSlider = false),
                      backgroundColor: palette.paper,
                      foregroundColor: palette.lyric,
                      activeColor: palette.toolbarIcon,
                      inactiveColor: palette.divider,
                      dividerColor: palette.divider,
                    ),
                  Expanded(
                    child: docAsync.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: palette.toolbarIcon,
                        ),
                      ),
                      error: (_, _) => _Message(
                        message: l10n.gesturesReaderUnavailable,
                        color: palette.sectionLabel,
                        onTap: () {
                          ref.invalidate(gestureDocumentProvider(_r2Key));
                          // Um dicionário sem sinal na primeira abertura
                          // também merece outra chance no retoque manual.
                          ref.invalidate(gestureDictionaryProvider);
                        },
                        key: gestureReaderRetryKey,
                      ),
                      data: (document) {
                        if (document == null) {
                          return _Message(
                            message: l10n.gesturesReaderEmpty,
                            color: palette.sectionLabel,
                          );
                        }
                        if (dictionary.byId.isNotEmpty) {
                          _maybePrefetch(document, dictionary);
                        }
                        // Leitura linear: expande antes da página, do flatten
                        // e do foco, para os três falarem do mesmo índice.
                        final shown = linear
                            ? linearizeGestureDocument(document)
                            : document;
                        final flat = flattenGestureCards(shown);
                        return Column(
                          children: [
                            if (document.isNewerSchema)
                              const NewerSchemaBanner(),
                            Expanded(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: _onScrollNotification,
                                child: GestureDocumentView(
                                  key: _documentViewKey,
                                  document: shown,
                                  dictionary: dictionary,
                                  fontSize: fontSize,
                                  palette: palette,
                                  scrollController: _scrollController,
                                  onCardTap: flat.isEmpty
                                      ? null
                                      : (index) => _openFocus(
                                          flat,
                                          dictionary,
                                          index,
                                          fontSize,
                                          palette,
                                        ),
                                ),
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
  const _Message({
    required this.message,
    required this.color,
    this.onTap,
    super.key,
  });

  final String message;
  final Color color;
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
            style: AppTypography.body.copyWith(color: color),
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

/// Barra 3: corpo da letra, autoscroll, linear/estruturado, tema, tela cheia.
///
/// Espelho de `_ChordReaderToolbar`: ícones na cor da paleta e um traço entre
/// grupos — sem ele os botões se leem como uma fileira de controles iguais.
class _GestureReaderToolbar extends ConsumerWidget {
  const _GestureReaderToolbar({
    required this.mode,
    required this.palette,
    required this.fontSize,
    required this.linear,
    required this.autoscroll,
    required this.showSpeedSlider,
    required this.onToggleSpeedSlider,
    required this.l10n,
    required this.gestureId,
    this.praiseId,
  });

  final String? praiseId;

  final GestureReaderMode mode;
  final GestureReaderPalette palette;
  final double fontSize;
  final bool linear;
  final GestureAutoscrollState autoscroll;
  final bool showSpeedSlider;
  final VoidCallback onToggleSpeedSlider;
  final AppLocalizations l10n;
  final String gestureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(gestureReaderFontSizeProvider.notifier);
    final autoscrollNotifier = ref.read(gestureAutoscrollProvider.notifier);
    final style = _toolbarButtonStyle(palette.toolbarIcon);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _toolbarGroupGap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderDecreaseFont,
            icon: const Icon(Icons.text_decrease),
            onPressed: GestureReaderFontSize.canDecrease(fontSize)
                ? size.decrease
                : null,
          ),
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderIncreaseFont,
            icon: const Icon(Icons.text_increase),
            onPressed: GestureReaderFontSize.canIncrease(fontSize)
                ? size.increase
                : null,
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            key: gestureReaderAutoscrollKey,
            style: style,
            tooltip: autoscroll.running
                ? l10n.gesturesAutoscrollPause
                : l10n.gesturesAutoscrollPlay,
            icon: Icon(
              autoscroll.running
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            onPressed: autoscrollNotifier.toggle,
          ),
          SizedBox(
            width: _speedLabelWidth,
            child: IconButton(
              key: gestureReaderSpeedKey,
              style: IconButton.styleFrom(
                foregroundColor: palette.toolbarIcon,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                minimumSize: const Size(_speedLabelWidth, 40),
              ),
              tooltip: l10n.autoscrollSpeedTooltip,
              icon: Icon(
                Icons.speed,
                color: showSpeedSlider ? palette.toolbarIcon : null,
              ),
              onPressed: onToggleSpeedSlider,
            ),
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            key: gestureReaderLinearKey,
            style: style,
            // O ícone mostra o estado atual; o tooltip, a ação.
            tooltip: linear
                ? l10n.gesturesReaderStructured
                : l10n.gesturesReaderLinear,
            icon: Icon(
              linear ? Icons.view_agenda_outlined : Icons.account_tree_outlined,
            ),
            onPressed: () =>
                ref.read(gestureReaderLinearProvider.notifier).toggle(),
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            key: gestureReaderThemeKey,
            style: style,
            tooltip: l10n.gesturesReaderToggleTheme,
            icon: Icon(
              mode == GestureReaderMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () =>
                ref.read(gestureReaderModeProvider.notifier).toggle(),
          ),
          IconButton(
            key: gestureReaderFullscreenKey,
            style: style,
            tooltip: ref.watch(readerFullscreenProvider)
                ? l10n.readerExitFullscreenTooltip
                : l10n.gesturesReaderFullscreen,
            icon: Icon(
              ref.watch(readerFullscreenProvider)
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
            ),
            onPressed: () => ref.read(toggleReaderFullscreenProvider).call(),
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            style: style,
            tooltip: l10n.contributeReportTooltip,
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () {
              final lookupPraiseId = ref
                  .read(catalogMaterialLookupProvider)
                  .gesture(gestureId)
                  ?.groupId;
              final sourcePraiseId = ref
                  .read(coldigomCatalogSourceProvider)
                  .findGroupForMaterial(gestureId)
                  ?.groupId;
              final effectivePraiseId =
                  (lookupPraiseId != null && lookupPraiseId.isNotEmpty)
                      ? lookupPraiseId
                      : ((sourcePraiseId != null && sourcePraiseId.isNotEmpty)
                          ? sourcePraiseId
                          : praiseId);
              openContribute(
                context,
                target: ContributionTarget(
                  source: ContributionSource.coldigom,
                  praiseId: effectivePraiseId,
                  materialId: gestureId,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Traço entre grupos de controles.
class _ToolbarSeparator extends StatelessWidget {
  const _ToolbarSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: _toolbarGroupGap / 2),
      color: color,
    );
  }
}
