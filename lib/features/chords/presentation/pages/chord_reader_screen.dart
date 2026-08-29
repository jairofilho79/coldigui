import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/chord_providers.dart';
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
    final songAsync = ref.watch(chordSongProvider(_r2Key));

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.chordReaderToggleTheme,
                icon: Icon(
                  mode == ChordReaderMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: palette.chord,
                ),
                onPressed: () =>
                    ref.read(chordReaderModeProvider.notifier).toggle(),
              ),
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
                        if (_headerMeta(song.subtitle, song.key, song.rhythm,
                                song.artist)
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: Text(
                              _headerMeta(song.subtitle, song.key, song.rhythm,
                                  song.artist),
                              style: AppTypography.label.copyWith(
                                color: palette.comment,
                              ),
                            ),
                          ),
                        ChordProView(song: song, palette: palette),
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
