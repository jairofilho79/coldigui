import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/saved_playlist.dart';
import '../exceptions/invalid_share_playlist_exception.dart';
import '../repositories/playlist_repository.dart';
import '../utils/content_fingerprint.dart';

/// Resultado de [ImportSharedPlaylistFromUrl.call] (D7, spec C.2).
class ImportResult {
  const ImportResult({required this.playlist, required this.alreadyExisted});

  /// A lista salva — nova, ou a já existente reaproveitada.
  final SavedPlaylist playlist;

  /// `true` quando já havia uma lista salva com o mesmo conteúdo: nenhuma
  /// lista nova foi criada, [playlist] é a existente.
  final bool alreadyExisted;
}

/// UC-07 — Importar playlist compartilhada (Fase 4.4).
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(this._playlistRepository);

  final PlaylistRepository _playlistRepository;

  /// Persiste a nova playlist (ou reaproveita uma existente) e devolve o
  /// [ImportResult].
  ///
  /// [shareItems] (v2, spec A.5) preserva a ordem intercalada e o tipo de cada
  /// material; quando ausente ou inválido, [sharePdfs]/[shareAudios] valem como
  /// antes. Quem chama torna a lista ativa (D3) — não existe mais carousel a
  /// carregar.
  ///
  /// **Dedupe por conteúdo (spec C.2):** antes de criar, procura entre as
  /// listas salvas e não apagadas ([PlaylistRepository.getAll] filtrando
  /// `salva && deletedAt == null`) uma com o mesmo [contentFingerprint]
  /// (`kind:id` por entrada, na ordem — o nome do link não entra na conta).
  /// Se existir, não cria: devolve a lista existente com
  /// `alreadyExisted: true`.
  ///
  /// [excludePlaylistId] (fix round 2, Minor) tira uma lista específica da
  /// dedupe — a que está na graça de uma exclusão adiada (C11): o repositório
  /// ainda não sabe que ela foi apagada (`deletedAt` só é gravado no
  /// `commit`, que pode nunca rodar se o usuário desfizer), então o filtro de
  /// tombstone abaixo não a pega sozinho.
  ///
  /// Lança [InvalidSharePlaylistException] se params inválidos.
  Future<ImportResult> call({
    required String shareName,
    String sharePdfs = '',
    String shareAudios = '',
    String shareItems = '',
    String? excludePlaylistId,
  }) async {
    final params = PlaylistShareParams(
      sharePdfs: sharePdfs,
      shareAudios: shareAudios,
      shareName: shareName,
      shareItems: shareItems.isEmpty ? null : shareItems,
    );
    final entries = params.entries;
    final nome = shareName.trim();
    if (entries.isEmpty || nome.isEmpty) {
      throw const InvalidSharePlaylistException();
    }

    final fingerprint = contentFingerprint(entries);
    final saved = await _playlistRepository.getAll();
    for (final playlist in saved) {
      if (!playlist.salva || playlist.deletedAt != null) continue;
      if (playlist.playlistId == excludePlaylistId) continue;
      if (contentFingerprint(playlist.entries) == fingerprint) {
        return ImportResult(playlist: playlist, alreadyExisted: true);
      }
    }

    final now = DateTime.now();
    final playlistId = await _playlistRepository.create(
      nome: nome,
      entries: entries,
      salva: true,
      savedAt: now,
    );
    final created = await _playlistRepository.getById(playlistId);
    return ImportResult(playlist: created!, alreadyExisted: false);
  }
}
