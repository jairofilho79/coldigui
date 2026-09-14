import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';
import '../providers/lyrics_reader_font_size_provider.dart';

/// Leitor de letra Coldigom (`/letra?praiseId=`) — O6.
///
/// Lê o texto do Isar ([coldigomCatalogLocalDatasourceProvider]), nunca da
/// rede: a letra vem inteira no dump do catálogo e está sempre offline.
/// Filho da branch Home como `/cifra`: o shell dá o cabeçalho e a barra do
/// carousel; aqui só há a barra de A−/A+ e o texto selecionável.
class LyricsReaderScreen extends ConsumerWidget {
  const LyricsReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  String get _praiseId => queryParams[UrlSyncParams.praiseId] ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = ref.watch(lyricsReaderFontSizeProvider);
    final row = ref
        .watch(coldigomCatalogLocalDatasourceProvider)
        .findByPraiseIdSync(_praiseId);
    final title = queryParams[UrlSyncParams.titulo] ?? row?.name ?? '';
    final text = row?.lyrics.trim() ?? '';

    return ColoredBox(
      color: AppColors.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LyricsToolbar(title: title, fontSize: fontSize, l10n: l10n),
            const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
            Expanded(
              child: text.isEmpty
                  ? Center(
                      child: Text(
                        l10n.lyricsReaderEmpty,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textDark.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: SelectableText(
                        text,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textDark,
                          fontSize: fontSize,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título do louvor + A−/A+.
class _LyricsToolbar extends ConsumerWidget {
  const _LyricsToolbar({
    required this.title,
    required this.fontSize,
    required this.l10n,
  });

  final String title;
  final double fontSize;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(lyricsReaderFontSizeProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.isEmpty ? l10n.lyricsTitle : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headline.copyWith(
                color: AppColors.title,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.lyricsReaderDecreaseFont,
            icon: const Icon(Icons.text_decrease, color: AppColors.title),
            onPressed: LyricsReaderFontSize.canDecrease(fontSize)
                ? size.decrease
                : null,
          ),
          IconButton(
            tooltip: l10n.lyricsReaderIncreaseFont,
            icon: const Icon(Icons.text_increase, color: AppColors.title),
            onPressed: LyricsReaderFontSize.canIncrease(fontSize)
                ? size.increase
                : null,
          ),
        ],
      ),
    );
  }
}
