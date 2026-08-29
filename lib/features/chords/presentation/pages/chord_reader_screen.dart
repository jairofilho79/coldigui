import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
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

    return ColoredBox(
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
                loading: () => const Center(child: CircularProgressIndicator()),
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
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
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
    );
  }

  /// Cabeçalho com o tom já transposto — o músico lê o tom em que vai tocar,
  /// não o do arquivo.
  String _headerMeta(String subtitle, String key, String rhythm, String artist) {
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

/// Barra compacta do leitor: tema, corpo da letra e transposição.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ToolbarButton(
            tooltip: l10n.chordReaderTransposeDown,
            icon: Icons.remove,
            color: palette.chord,
            onPressed: semitones > -ChordReaderTransposeNotifier.limit
                ? transpose.down
                : null,
          ),
          // Rótulo do deslocamento: toque volta ao tom original. Só aparece
          // transposto — em zero não há o que desfazer.
          if (semitones != 0)
            Tooltip(
              message: l10n.chordReaderResetTranspose,
              child: InkWell(
                onTap: transpose.reset,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    semitones > 0 ? '+$semitones' : '$semitones',
                    style: AppTypography.label.copyWith(
                      color: palette.chord,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          _ToolbarButton(
            tooltip: l10n.chordReaderTransposeUp,
            icon: Icons.add,
            color: palette.chord,
            onPressed: semitones < ChordReaderTransposeNotifier.limit
                ? transpose.up
                : null,
          ),
          SizedBox(
            height: 20,
            child: VerticalDivider(color: palette.comment, width: 12),
          ),
          _ToolbarButton(
            tooltip: l10n.chordReaderDecreaseFont,
            icon: Icons.text_decrease,
            color: palette.chord,
            onPressed: ChordReaderFontSize.canDecrease(fontSize)
                ? size.decrease
                : null,
          ),
          _ToolbarButton(
            tooltip: l10n.chordReaderIncreaseFont,
            icon: Icons.text_increase,
            color: palette.chord,
            onPressed: ChordReaderFontSize.canIncrease(fontSize)
                ? size.increase
                : null,
          ),
          _ToolbarButton(
            tooltip: l10n.chordReaderToggleTheme,
            icon: mode == ChordReaderMode.light
                ? Icons.dark_mode
                : Icons.light_mode,
            color: palette.chord,
            onPressed: () => ref.read(chordReaderModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

/// Botão da barra — compacto para caber a fileira inteira em tela estreita.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      color: color,
      disabledColor: color.withValues(alpha: 0.3),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}
