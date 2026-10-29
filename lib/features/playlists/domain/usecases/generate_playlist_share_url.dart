import '../../../../core/constants/share_config.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../entities/saved_playlist.dart';
import '../exceptions/empty_playlist_share_exception.dart';
import '../exceptions/playlist_not_found_exception.dart';
import '../exceptions/praise_short_id_unavailable_exception.dart';
import '../repositories/playlist_repository.dart';

final _log = AppLogger.of('playlists');

/// Id de uma entrada da lista → `shortId` do praise dela, pelo catálogo local
/// (spec fim-fonte-plpcg §4.2) — nunca pelo path do id (materiais movidos).
/// `null` = material fora do índice ou praise sem `shortId`.
typedef PraiseShortIdLookup = String? Function(String entryId);

/// Link por praise gerado por [GeneratePlaylistShareUrl.generate].
class PlaylistShareLink {
  const PlaylistShareLink({required this.url, required this.skippedCount});

  /// URL absoluta `…/?p=…&n=…`.
  final String url;

  /// Entradas legadas órfãs (fora do espaço Coldigom) que ficaram fora do
  /// link — o share segue e a UI avisa quantas.
  final int skippedCount;
}

/// UC-07 — gerar o link de compartilhamento por praise (`?p=…&n=…`).
///
/// [call] devolve só a URL; [generate] devolve também quantas entradas
/// ficaram de fora ([PlaylistShareLink]) para quem avisa o usuário.
class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(
    this._repository, {
    required this.praiseShortIdOf,
    this.shareOrigin = ShareConfig.appOrigin,
  });

  final PlaylistRepository _repository;
  final PraiseShortIdLookup praiseShortIdOf;
  final String shareOrigin;

  /// Um token por entrada, na ordem da lista. Repetidos ficam: duas entradas
  /// do mesmo praise viram o mesmo token duas vezes. Qualquer kind serve
  /// (PDF, áudio, cifra, gesto, letra, YouTube).
  ///
  /// Entrada que o índice não resolve e cujo id está fora do espaço Coldigom
  /// (legado órfão do acervo PLPCG) fica de fora do link em vez de falhar o
  /// share — desvio deliberado do §4.2.
  ///
  /// Lança [PlaylistNotFoundException], [EmptyPlaylistShareException] (lista
  /// vazia ou só com legados) ou [PraiseShortIdUnavailableException] (com os
  /// ids Coldigom sem token) — o link nunca sai com louvores do catálogo a
  /// menos.
  Future<String> call({required String playlistId}) async =>
      (await generate(playlistId: playlistId)).url;

  /// Como [call], mas devolve também o número de entradas legadas que
  /// ficaram de fora do link ([PlaylistShareLink.skippedCount]).
  Future<PlaylistShareLink> generate({required String playlistId}) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) throw const PlaylistNotFoundException();
    if (playlist.entries.isEmpty) throw const EmptyPlaylistShareException();

    final shortIds = <String>[];
    final missing = <String>[];
    var skipped = 0;
    for (final entry in playlist.entries) {
      // O índice primeiro: um YouTube gravado como `unknown` (listas
      // legadas, `addToActive` sem kind) não decodifica, mas o catálogo o
      // conhece. O índice só tem ids Coldigom — legado nunca resolve aqui.
      final shortId = praiseShortIdOf(entry.id)?.trim().toLowerCase();
      if (shortId != null && isPraiseShortId(shortId)) {
        shortIds.add(shortId);
      } else if (!_inColdigomIdSpace(entry)) {
        skipped++;
      } else {
        missing.add(entry.id);
      }
    }
    if (skipped > 0) {
      _log.info('link da lista sem $skipped entrada(s) fora do Coldigom');
    }
    if (missing.isNotEmpty) throw PraiseShortIdUnavailableException(missing);
    if (shortIds.isEmpty) throw const EmptyPlaylistShareException();

    return PlaylistShareLink(
      url: buildPraiseShareUrl(
        origin: shareOrigin,
        praiseShortIds: shortIds,
        shareName: playlist.nome,
      ),
      skippedCount: skipped,
    );
  }

  /// `false` só para id que não pode ser do Coldigom: nem path
  /// `assets/praises/…` (PDF, cifra, gesto, áudio), nem `lyrics:<praiseId>`,
  /// nem YouTube (id do Worker, Coldigom por construção).
  static bool _inColdigomIdSpace(PlaylistEntry entry) =>
      entry.kind == MaterialKind.youtube ||
      materialIdKindOf(entry.id) == MaterialKind.lyrics ||
      isColdigomPdfId(entry.id);
}
