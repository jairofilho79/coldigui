// test/unit/features/playlists/playlist_count_label_test.dart
//
// Formas do rótulo de contagem do cabeçalho de `PlaylistListTile` (spec
// 2026-09-12, §9) — «3 partituras · 1 áudio», «1 áudio», «Vazia».
import 'package:coldigui/features/playlists/presentation/utils/playlist_count_label.dart';
import 'package:coldigui/l10n/app_localizations_pt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsPt();

  test('partituras e áudios: junta as duas partes com « · »', () {
    expect(
      playlistCountLabel(l10n, pdfs: 3, audios: 1),
      '3 partituras · 1 áudio',
    );
  });

  test('só áudio: omite a parte de partituras zerada', () {
    expect(playlistCountLabel(l10n, pdfs: 0, audios: 1), '1 áudio');
  });

  test('só partitura: omite a parte de áudio zerada', () {
    expect(playlistCountLabel(l10n, pdfs: 1, audios: 0), '1 partitura');
  });

  test('sem nenhum dos dois: «Vazia»', () {
    expect(playlistCountLabel(l10n, pdfs: 0, audios: 0), 'Vazia');
  });
}
