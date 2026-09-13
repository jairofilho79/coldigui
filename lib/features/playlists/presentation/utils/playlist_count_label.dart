import '../../../../l10n/app_localizations.dart';

/// Rótulo de contagem do cabeçalho de [PlaylistListTile] (spec 2026-09-12,
/// §9): «3 partituras · 1 áudio»; omite a parte zerada; «Vazia» sem nenhuma.
///
/// Extraído de `_countLabel` (E4) para poder ser testado sem montar o tile
/// inteiro.
String playlistCountLabel(
  AppLocalizations l10n, {
  required int pdfs,
  required int audios,
}) {
  final parts = <String>[
    if (pdfs > 0) l10n.playlistSheetCount(pdfs),
    if (audios > 0) l10n.playlistAudioOnlyCount(audios),
  ];
  return parts.isEmpty ? l10n.playlistEmptyCount : parts.join(' · ');
}
