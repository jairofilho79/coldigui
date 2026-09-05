import '../../../catalog/domain/entities/louvor.dart';
import '../../../playlists/domain/entities/playlist_entry.dart';
import '../../../playlists/domain/repositories/playlist_repository.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/catalog_pdf_id_remap.dart';

/// Reconcilia `pdfId`s obsoletos após atualização do manifest.
///
/// Quando um louvor é substituído (novo caminho → novo `pdfId`), remapeia o
/// índice offline e as listas. O carousel saiu (D3): a seleção **é** a lista
/// ativa, então remapear as listas já cobre a barra.
class RemapPdfIdsAfterCatalogUpdate {
  const RemapPdfIdsAfterCatalogUpdate(
    this._offlineRepository,
    this._playlistRepository,
  );

  final OfflinePdfRepository _offlineRepository;
  final PlaylistRepository _playlistRepository;

  Future<void> call({
    required List<Louvor> previousLouvores,
    required List<Louvor> newLouvores,
  }) async {
    final remappings = computeCatalogPdfIdRemappings(
      previousLouvores: previousLouvores,
      newLouvores: newLouvores,
    );
    if (remappings.isEmpty) return;

    for (final entry in remappings.entries) {
      await _offlineRepository.remapPdfId(
        fromPdfId: entry.key,
        toPdfId: entry.value,
      );
    }

    final playlists = await _playlistRepository.getAll();
    for (final playlist in playlists) {
      // Remapeia por posição, preservando o `kind` declarado: um id trocado no
      // manifest continua sendo o mesmo tipo de material.
      final remapped = <PlaylistEntry>[
        for (final entry in playlist.entries)
          PlaylistEntry(id: remappings[entry.id] ?? entry.id, kind: entry.kind),
      ];
      if (!_entriesEqual(playlist.entries, remapped)) {
        await _playlistRepository.update(
          playlist.playlistId,
          entries: remapped,
        );
      }
    }
  }

  static bool _entriesEqual(List<PlaylistEntry> a, List<PlaylistEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
