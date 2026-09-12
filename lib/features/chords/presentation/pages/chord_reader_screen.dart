import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/presentation/widgets/reader_split_layout.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../../audio_player/presentation/widgets/mini_player_bar_metrics.dart';
import '../../../carousel/domain/entities/carousel_item.dart';
import '../../../carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import '../../../carousel/presentation/widgets/active_list_panel.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_side_panel_provider.dart';
import '../../data/providers/chord_providers.dart';
import '../../domain/entities/chord_reader_font_size.dart';
import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/transpose_chord.dart';
import '../providers/chord_autoscroll_provider.dart';
import '../providers/chord_reader_mode_provider.dart';
import '../theme/chord_reader_theme.dart';
import '../utils/transpose_label_memo.dart';
import '../widgets/chordpro_view.dart';

/// Leitor de cifras ChordPro — rota `/cifra`, filha do [ShellScaffold].
///
/// Barras 1–2 (PLPCG + carousel) vêm do shell, como em `/leitor`. Esta tela
/// renderiza o cabeçalho da música, o corpo e o toggle de tema.
///
/// Recebe [UrlSyncParams.pdfId] (id da cifra, mesmo espaço do PDF),
/// [UrlSyncParams.titulo] e [UrlSyncParams.subtitulo]. Publica os params em
/// [readerRouteParamsProvider] para [CarouselChips] sincronizar o chip focado.
class ChordReaderScreen extends ConsumerStatefulWidget {
  const ChordReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<ChordReaderScreen> createState() => _ChordReaderScreenState();
}

class _ChordReaderScreenState extends ConsumerState<ChordReaderScreen>
    with SingleTickerProviderStateMixin {
  late final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'chordReaderKeys',
  );
  final ScrollController _scrollController = ScrollController();
  final TransposeLabelMemo _transposeMemo = TransposeLabelMemo();
  var _louvorNavigationInProgress = false;

  Ticker? _autoscrollTicker;
  Duration? _autoscrollLastTick;

  @override
  void initState() {
    super.initState();
    _schedulePublishRouteParams();
  }

  @override
  void didUpdateWidget(covariant ChordReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryParams != widget.queryParams) {
      _schedulePublishRouteParams();
    }
    final oldId = oldWidget.queryParams[UrlSyncParams.pdfId];
    final newId = widget.queryParams[UrlSyncParams.pdfId];
    // C9: o autoscroll não atravessa a troca de louvor — sem isso a rolagem
    // automática de uma música continuaria correndo sozinha na próxima.
    if (oldId != newId) _stopAutoscroll();
  }

  void _schedulePublishRouteParams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  @override
  void dispose() {
    _autoscrollTicker?.dispose();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
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

  /// Toque num item do painel lateral (A.6 C7): mesma ação das chips — foca a
  /// ocorrência (já feito por [ActiveListPanel]) e troca o material aberto no
  /// leitor. No-op quando o item tocado já é o material aberto (só a
  /// ocorrência focada muda).
  Future<void> _openFromPanel(CarouselItem item) async {
    final currentPdfId = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (currentPdfId.isNotEmpty && item.materialId == currentPdfId) return;

    await openCarouselPdfInReader(
      ref: ref,
      context: context,
      materialId: item.materialId,
      navigate: (location) async {
        if (!mounted) return;
        context.replace(location);
      },
    );
  }

  /// Teclado do leitor de cifras (C1, C9).
  ///
  /// `+`/`=` e `-` transpõem, `Ctrl+↑/↓` mexem no corpo da letra e `Ctrl+→/←`
  /// trocam de louvor. O `=` entra junto do `+` porque na maioria dos teclados
  /// é a mesma tecla — cobrar o Shift seria cobrar precisão de quem está com o
  /// violão na mão. `S` liga/desliga o autoscroll e `[`/`]` regulam sua
  /// velocidade — essas três, como a busca (`/`) em [AppShortcuts], não valem
  /// com o foco num campo de texto. Teclas fora desta lista sobem para
  /// [AppShortcuts] (`F`, `Esc`, `Espaço`).
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    final commandModifier = keyboard.isControlPressed || keyboard.isMetaPressed;
    final key = event.logicalKey;

    if (commandModifier) {
      if (key == LogicalKeyboardKey.arrowUp) {
        ref.read(chordReaderFontSizeProvider.notifier).increase();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        ref.read(chordReaderFontSizeProvider.notifier).decrease();
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

    if (_isTransposeUpKey(key, event.character)) {
      ref.read(chordReaderTransposeProvider(_r2Key).notifier).up();
      return KeyEventResult.handled;
    }
    if (_isTransposeDownKey(key, event.character)) {
      ref.read(chordReaderTransposeProvider(_r2Key).notifier).down();
      return KeyEventResult.handled;
    }

    if (!keyboardFocusIsInsideTextField()) {
      if (key == LogicalKeyboardKey.keyS) {
        ref.read(chordAutoscrollProvider.notifier).toggle();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketRight) {
        final speed = ref.read(chordAutoscrollProvider).speed;
        ref.read(chordAutoscrollProvider.notifier).setSpeed(speed + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketLeft) {
        final speed = ref.read(chordAutoscrollProvider).speed;
        ref.read(chordAutoscrollProvider.notifier).setSpeed(speed - 1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  static bool _isTransposeUpKey(LogicalKeyboardKey key, String? character) {
    return key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        character == '+' ||
        character == '=';
  }

  static bool _isTransposeDownKey(LogicalKeyboardKey key, String? character) {
    return key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        character == '-';
  }

  /// `r2Key` decodificado do id da rota; vazio se o id faltar ou for inválido.
  ///
  /// Dobra como a chave da família de [chordReaderTransposeProvider] (C10):
  /// cada cifra guarda seu próprio tom nesta sessão.
  String get _r2Key {
    final id = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (id.isEmpty) return '';
    try {
      return PdfPathNormalizer.getPdfRelPath(id);
    } on Object {
      return '';
    }
  }

  /// Garante o `Ticker` do autoscroll rodando (C9).
  ///
  /// `Ticker`, não `Timer`: sincroniza com o vsync do resto da UI e para
  /// sozinho quando a tela sai de cena (`SingleTickerProviderStateMixin`
  /// cobra isso na hora de descartar o `State`).
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

    if (!ref.read(chordAutoscrollProvider).running) {
      _autoscrollTicker?.stop();
      return;
    }
    if (!_scrollController.hasClients) return;

    final dtSeconds =
        (elapsed - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    if (dtSeconds <= 0) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      ref.read(chordAutoscrollProvider.notifier).stop();
      return;
    }

    final speed = ref.read(chordAutoscrollProvider).speed;
    final delta = speed * kChordAutoscrollPxPerSecondPerSpeed * dtSeconds;
    final next = (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(next);

    if (next >= position.maxScrollExtent) {
      ref.read(chordAutoscrollProvider.notifier).stop();
    }
  }

  /// Para o autoscroll ao trocar de louvor (C9).
  ///
  /// O `Ticker` pode parar na hora — não é estado do Riverpod. Mas o
  /// `chordAutoscrollProvider` não pode ser escrito aqui dentro: este método
  /// só é chamado de [didUpdateWidget], e o Riverpod proíbe modificar um
  /// provider durante um ciclo de vida de widget (build/didUpdateWidget/...) —
  /// escrever `state` synchronamente lançaria "Tried to modify a provider
  /// while the widget tree was building". Adia para o próximo frame, como
  /// [_schedulePublishRouteParams] já faz para o mesmo motivo.
  void _stopAutoscroll() {
    _autoscrollTicker?.stop();
    if (!ref.read(chordAutoscrollProvider).running) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chordAutoscrollProvider.notifier).stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(chordReaderModeProvider);
    final palette = mode.palette;
    final fontSize = ref.watch(chordReaderFontSizeProvider);
    final r2Key = _r2Key;
    final semitones = ref.watch(chordReaderTransposeProvider(r2Key));
    final songAsync = ref.watch(chordSongProvider(r2Key));
    final autoscroll = ref.watch(chordAutoscrollProvider);
    final sidePanelOpen = ref.watch(readerSidePanelOpenProvider);
    final panel = ActiveListPanel(onOpen: _openFromPanel);
    // Important 3 (onda 4): mesma condição do overlay em `shell_scaffold.dart`
    // — reserva espaço para as últimas linhas não ficarem cobertas por ele.
    final isFullscreen = ref.watch(readerFullscreenProvider);
    final hasPlayingTrack = ref.watch(
      audioPlayerSessionProvider.select((s) => s.currentTrack != null),
    );
    final bottomPadding =
        24.0 + (isFullscreen && hasPlayingTrack ? kMiniPlayerBarHeight : 0);

    // Liga/desliga o motor do Ticker junto da intenção do usuário — o
    // provider só guarda o estado, quem move o scroll é este `State`.
    ref.listen<ChordAutoscrollState>(chordAutoscrollProvider, (previous, next) {
      if (next.running) {
        _ensureAutoscrollTicker();
      } else {
        _autoscrollTicker?.stop();
      }
    });

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        // Rolar/clicar na cifra devolve o teclado ao leitor depois de um
        // desvio pelos botões da barra.
        onPointerDown: (_) => _keyboardFocusNode.requestFocus(),
        child: ColoredBox(
          color: palette.background,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChordReaderToolbar(
                  mode: mode,
                  palette: palette,
                  fontSize: fontSize,
                  semitones: semitones,
                  chordId: r2Key,
                  autoscroll: autoscroll,
                  l10n: l10n,
                  sidePanelOpen: sidePanelOpen,
                  onToggleSidePanel: () =>
                      ref.read(readerSidePanelOpenProvider.notifier).toggle(),
                  sidePanelTooltip: sidePanelOpen
                      ? l10n.readerSidePanelHideTooltip
                      : l10n.readerSidePanelShowTooltip,
                ),
                Expanded(
                  child: ReaderSplitLayout(
                    panel: ColoredBox(color: palette.background, child: panel),
                    // Important 4 (onda 4): colunas pela largura DISPONÍVEL
                    // (depois do painel lateral tirar `panelWidth`), não pela
                    // largura da tela inteira — `LayoutBuilder` aqui já mede
                    // o espaço real desta área (dentro do `Expanded` acima,
                    // ao lado do painel quando ele está aberto).
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= kWideLayoutBreakpoint
                            ? 2
                            : 1;
                        return songAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => _Unavailable(
                            message: l10n.chordReaderUnavailable,
                            palette: palette,
                          ),
                          data: (song) {
                            if (song == null) {
                              return _Unavailable(
                                message: l10n.chordReaderUnavailable,
                                palette: palette,
                              );
                            }
                            return NotificationListener<UserScrollNotification>(
                              // A11: rolar com o dedo/mouse é o jeito mais
                              // claro de dizer "eu assumo daqui" — para o
                              // autoscroll na hora, sem esperar o usuário
                              // achar o botão de pausa.
                              onNotification: (notification) {
                                if (notification.direction !=
                                    ScrollDirection.idle) {
                                  ref
                                      .read(chordAutoscrollProvider.notifier)
                                      .stop();
                                }
                                return false;
                              },
                              child: CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    sliver: SliverToBoxAdapter(
                                      child: _ChordHeader(
                                        song: song,
                                        semitones: semitones,
                                        palette: palette,
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      bottomPadding,
                                    ),
                                    sliver: ChordProView(
                                      song: song,
                                      palette: palette,
                                      fontSize: fontSize,
                                      semitones: semitones,
                                      memo: _transposeMemo,
                                      columns: columns,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título e metadados (subtítulo, tom já transposto, ritmo, artista).
class _ChordHeader extends StatelessWidget {
  const _ChordHeader({
    required this.song,
    required this.semitones,
    required this.palette,
  });

  final ChordProSong song;
  final int semitones;
  final ChordReaderPalette palette;

  /// Cabeçalho com o tom já transposto — o músico lê o tom em que vai tocar,
  /// não o do arquivo.
  String get _meta {
    return [
      if (song.subtitle.isNotEmpty) song.subtitle,
      if (transposeKeyLabel(song.key, semitones).isNotEmpty)
        transposeKeyLabel(song.key, semitones),
      if (song.rhythm.isNotEmpty) song.rhythm,
      if (song.artist.isNotEmpty) song.artist,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (song.title.isNotEmpty)
          Text(
            song.title,
            style: AppTypography.headline.copyWith(color: palette.chord),
          ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              meta,
              style: AppTypography.label.copyWith(color: palette.comment),
            ),
          ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.palette});

  final String message;
  final ChordReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: palette.lyric),
        ),
      ),
    );
  }
}

/// Largura reservada ao rótulo de transposição.
///
/// Fixa mesmo em zero: sem isso o rótulo surge ao primeiro toque e empurra os
/// botões à sua esquerda, tirando o `−` de baixo do dedo justo quando o usuário
/// está repetindo o toque.
const _transposeLabelWidth = 34.0;

/// Espaço entre grupos de controles — mesmo gap da barra de carousel.
const _toolbarGroupGap = 8.0;

/// Estilo dos botões da barra do leitor de cifras.
///
/// Espelha [carouselBarIconButtonStyle] na forma (densidade compacta, alvo de
/// 44pt, desabilitado no mesmo matiz) trocando só a cor, que aqui vem da paleta
/// clara/escura do leitor em vez de [AppColors]. O mínimo de 44 é o que
/// uniformiza o espaçamento: todo glifo cabe folgado, então cada botão ocupa
/// exatamente a mesma largura, independentemente de `add` ser mais estreito que
/// `text_increase`.
ButtonStyle _toolbarButtonStyle(Color color) => IconButton.styleFrom(
  foregroundColor: color,
  disabledForegroundColor: color.withValues(alpha: 0.38),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: const Size(44, 44),
);

/// Barra compacta do leitor: transposição, corpo da letra, autoscroll e tema.
///
/// Os controles ficam sempre visíveis porque o tom é o que mais se mexe durante
/// um ensaio — escondê-los num painel custaria dois toques a cada meio tom.
class _ChordReaderToolbar extends ConsumerWidget {
  const _ChordReaderToolbar({
    required this.mode,
    required this.palette,
    required this.fontSize,
    required this.semitones,
    required this.chordId,
    required this.autoscroll,
    required this.l10n,
    required this.sidePanelOpen,
    required this.onToggleSidePanel,
    required this.sidePanelTooltip,
  });

  final ChordReaderMode mode;
  final ChordReaderPalette palette;
  final double fontSize;
  final int semitones;

  /// Chave da família de [chordReaderTransposeProvider] (C10).
  final String chordId;
  final ChordAutoscrollState autoscroll;
  final AppLocalizations l10n;

  /// `true` quando o painel lateral (spec A.6 C7) está ligado — decide o
  /// tooltip do botão `Icons.view_sidebar`.
  final bool sidePanelOpen;
  final VoidCallback onToggleSidePanel;
  final String sidePanelTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transpose = ref.read(chordReaderTransposeProvider(chordId).notifier);
    final size = ref.read(chordReaderFontSizeProvider.notifier);
    final autoscrollNotifier = ref.read(chordAutoscrollProvider.notifier);
    final style = _toolbarButtonStyle(palette.chord);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _toolbarGroupGap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            style: style,
            tooltip: l10n.chordReaderTransposeDown,
            icon: const Icon(Icons.remove),
            onPressed: semitones > -ChordReaderTransposeNotifier.limit
                ? transpose.down
                : null,
          ),
          SizedBox(
            width: _transposeLabelWidth,
            child: semitones == 0
                ? null
                // TextButton, não InkWell: ele traz o próprio Material, e a
                // tela do leitor é um ColoredBox sem Scaffold acima.
                : TextButton(
                    onPressed: transpose.reset,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.chord,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(_transposeLabelWidth, 40),
                      textStyle: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Tooltip(
                      message: l10n.chordReaderResetTranspose,
                      child: Text(semitones > 0 ? '+$semitones' : '$semitones'),
                    ),
                  ),
          ),
          IconButton(
            style: style,
            tooltip: l10n.chordReaderTransposeUp,
            icon: const Icon(Icons.add),
            onPressed: semitones < ChordReaderTransposeNotifier.limit
                ? transpose.up
                : null,
          ),
          _ToolbarSeparator(color: palette.comment),
          IconButton(
            style: style,
            tooltip: l10n.chordReaderDecreaseFont,
            icon: const Icon(Icons.text_decrease),
            onPressed: ChordReaderFontSize.canDecrease(fontSize)
                ? size.decrease
                : null,
          ),
          IconButton(
            style: style,
            tooltip: l10n.chordReaderIncreaseFont,
            icon: const Icon(Icons.text_increase),
            onPressed: ChordReaderFontSize.canIncrease(fontSize)
                ? size.increase
                : null,
          ),
          _ToolbarSeparator(color: palette.comment),
          IconButton(
            style: style,
            tooltip: autoscroll.running
                ? l10n.chordAutoscrollPause
                : l10n.chordAutoscrollPlay,
            icon: Icon(
              autoscroll.running
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            onPressed: autoscrollNotifier.toggle,
          ),
          SizedBox(
            width: _transposeLabelWidth,
            child: TextButton(
              onPressed: () => autoscrollNotifier.setSpeed(
                autoscroll.speed >= kChordAutoscrollMaxSpeed
                    ? kChordAutoscrollMinSpeed
                    : autoscroll.speed + 1,
              ),
              style: TextButton.styleFrom(
                foregroundColor: palette.chord,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                minimumSize: const Size(_transposeLabelWidth, 40),
                textStyle: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Tooltip(
                message: l10n.chordAutoscrollSpeed(autoscroll.speed),
                child: Text('${autoscroll.speed}x'),
              ),
            ),
          ),
          _ToolbarSeparator(color: palette.comment),
          IconButton(
            style: style,
            tooltip: l10n.chordReaderToggleTheme,
            icon: Icon(
              mode == ChordReaderMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () =>
                ref.read(chordReaderModeProvider.notifier).toggle(),
          ),
          _ToolbarSeparator(color: palette.comment),
          IconButton(
            style: style,
            tooltip: sidePanelTooltip,
            icon: const Icon(Icons.view_sidebar),
            isSelected: sidePanelOpen,
            onPressed: onToggleSidePanel,
          ),
        ],
      ),
    );
  }
}

/// Traço entre grupos de controles.
///
/// Separa transposição, corpo, autoscroll e tema — sem ele os botões se leem
/// como uma fileira só de controles equivalentes.
class _ToolbarSeparator extends StatelessWidget {
  const _ToolbarSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: _toolbarGroupGap / 2),
      color: color.withValues(alpha: 0.4),
    );
  }
}
