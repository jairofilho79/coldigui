import '../entities/playlist_entry.dart';

/// `shortId` de praise → a entrada que o import grava (spec fim-fonte-plpcg
/// §4.3), com o material já escolhido: favorito da conta, senão PDF
/// principal → único áudio → primeiro adicionável. `null` = token
/// desconhecido no catálogo ou praise sem material adicionável — o import
/// salta.
typedef PraiseEntryResolver = PlaylistEntry? Function(String praiseShortId);

/// Espera o catálogo local (com prazo) e os favoritos e devolve o
/// [PraiseEntryResolver]. Com o prazo esgotado, o resolver devolve `null`
/// para tudo, e o import vira «link inválido» (§8).
typedef PraiseEntryResolverLoader = Future<PraiseEntryResolver> Function();
