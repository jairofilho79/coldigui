import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/chord_providers.dart';
import '../../domain/entities/chord_reader_font_size.dart';
import '../../domain/usecases/transpose_chord.dart';
import '../providers/chord_reader_mode_provider.dart';
import '../theme/chord_reader_theme.dart';
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

class _ChordReaderScreenState extends ConsumerState<ChordReaderScreen> {
  late final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'chordReaderKeys',
  );
  var _louvorNavigationInProgress = false;

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

  /// Teclado do leitor de cifras (C1).
  ///
  /// `+`/`=` e `-` transpõem, `Ctrl+↑/↓` mexem no corpo da letra e `Ctrl+→/←`
  /// trocam de louvor. O `=` entra junto do `+` porque na maioria dos teclados
  /// é a mesma tecla — cobrar o Shift seria cobrar precisão de quem está com o
  /// violão na mão. Teclas fora desta lista sobem para [AppShortcuts] (`F`,
  /// `Esc`, `Espaço`).
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
      ref.read(chordReaderTransposeProvider.notifier).up();
      return KeyEventResult.handled;
    }
    if (_isTransposeDownKey(key, event.character)) {
      ref.read(chordReaderTransposeProvider.notifier).down();
      return KeyEventResult.handled;
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
  String get _r2Key {
    final id = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (id.isEmpty) return '';
    try {
      return PdfPathNormalizer.getPdfRelPath(id);
    } on Object {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(chordReaderModeProvider);
    final palette = mode.palette;
    final fontSize = ref.watch(chordReaderFontSizeProvider);
    final semitones = ref.watch(chordReaderTransposeProvider);
    final songAsync = ref.watch(chordSongProvider(_r2Key));

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
                  l10n: l10n,
                ),
                Expanded(
                  child: songAsync.when(
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
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (song.title.isNotEmpty)
                              Text(
                                song.title,
                                style: AppTypography.headline.copyWith(
                                  color: palette.chord,
                                ),
                              ),
                            if (_headerMeta(
                              song.subtitle,
                              transposeKeyLabel(song.key, semitones),
                              song.rhythm,
                              song.artist,
                            ).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 12,
                                ),
                                child: Text(
                                  _headerMeta(
                                    song.subtitle,
                                    transposeKeyLabel(song.key, semitones),
                                    song.rhythm,
                                    song.artist,
                                  ),
                                  style: AppTypography.label.copyWith(
                                    color: palette.comment,
                                  ),
                                ),
                              ),
                            ChordProView(
                              song: song,
                              palette: palette,
                              fontSize: fontSize,
                              semitones: semitones,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cabeçalho com o tom já transposto — o músico lê o tom em que vai tocar,
  /// não o do arquivo.
  String _headerMeta(
    String subtitle,
    String key,
    String rhythm,
    String artist,
  ) {
    return [
      if (subtitle.isNotEmpty) subtitle,
      if (key.isNotEmpty) key,
      if (rhythm.isNotEmpty) rhythm,
      if (artist.isNotEmpty) artist,
    ].join(' · ');
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

/// Barra compacta do leitor: transposição, corpo da letra e tema.
///
/// Os controles ficam sempre visíveis porque o tom é o que mais se mexe durante
/// um ensaio — escondê-los num painel custaria dois toques a cada meio tom.
class _ChordReaderToolbar extends ConsumerWidget {
  const _ChordReaderToolbar({
    required this.mode,
    required this.palette,
    required this.fontSize,
    required this.semitones,
    required this.l10n,
  });

  final ChordReaderMode mode;
  final ChordReaderPalette palette;
  final double fontSize;
  final int semitones;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transpose = ref.read(chordReaderTransposeProvider.notifier);
    final size = ref.read(chordReaderFontSizeProvider.notifier);
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
            tooltip: l10n.chordReaderToggleTheme,
            icon: Icon(
              mode == ChordReaderMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () =>
                ref.read(chordReaderModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

/// Traço entre grupos de controles.
///
/// Separa transposição, corpo e tema — sem ele `−`/`+` e `A−`/`A+` se leem como
/// uma fileira só de quatro botões equivalentes.
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
