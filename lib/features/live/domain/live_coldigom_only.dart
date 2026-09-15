import '../../../core/utils/pdf_id_codec.dart';
import '../../playlists/domain/entities/playlist_entry.dart';

/// Regra «só Coldigom» da Lista ao Vivo.
///
/// O consumidor escolhe o **seu** material do louvor que o gestor foca
/// (favoritos por `material_kind`, sheet de materiais) — e isso só existe no
/// acervo Coldigom, onde um louvor tem vários materiais tipados. Um PDF do
/// acervo PLPCG não tem grupo nem `materialKindId`; por isso uma lista com
/// material PLPCG não sobe ao vivo.
///
/// Todo material Coldigom que entra na lista ativa codifica um path
/// `assets/praises/…` (PDF, cifra, gesto e áudio — mesmo codec); YouTube não
/// vive nesse espaço de ids mas é Coldigom por construção. Um id que não
/// decodifica é tratado como fora do acervo — melhor recusar do que
/// transmitir uma entrada que nenhum consumidor saberá resolver.
bool isColdigomEntry(PlaylistEntry entry) =>
    entry.kind == MaterialKind.youtube || isColdigomPdfId(entry.id);

/// Entradas de [entries] que não são do Coldigom, na ordem da lista.
/// Vazio quando a lista pode subir ao vivo.
List<PlaylistEntry> nonColdigomEntries(Iterable<PlaylistEntry> entries) => [
  for (final entry in entries)
    if (!isColdigomEntry(entry)) entry,
];
