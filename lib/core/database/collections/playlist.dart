import 'package:isar_plus/isar_plus.dart';

import 'playlist_publication.dart';
import 'playlist_sync_status.dart';

part 'playlist.g.dart';

/// Playlist do usuário (UC-06/07 + UC-15 sync).
///
/// [playlistId] é UUID estável; [items] é a ordem única dos materiais.
/// [salva] default `true` migra registros existentes como salvas.
@Collection()
class Playlist {
  int id = 0;

  @Index(unique: true)
  late String playlistId;

  late String nome;

  /// Projeção PDF/cifra de [items] — mantida em disco por compatibilidade
  /// (schema v1, share URL e Worker atual).
  late List<String> pdfIds;

  /// Projeção de áudio de [items] — mantida em disco por compatibilidade.
  List<String> audioIds = const [];

  late DateTime createdAt;

  /// `false` = lista não salva (rascunho automático ao abrir louvor).
  bool salva = true;

  DateTime? savedAt;
  DateTime? favoritedAt;
  bool favorita = false;

  /// Última mutação local/remota — merge last-write-wins.
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Versão otimista do servidor.
  int version = 1;

  /// Índice de [PlaylistSyncStatus] (0 synced … 3 conflict).
  int syncStatusIndex = 0;

  /// Soft delete local (tombstone até push remoto).
  DateTime? deletedAt;

  /// Publicação irreversível (metadados de alcance/categoria).
  bool isPublished = false;

  /// Índice de [PlaylistReach]; null se privada.
  int? publicationReachIndex;

  /// Índice de [PlaylistCategory]; null se privada.
  int? publicationCategoryIndex;

  DateTime? publishedAt;

  /// Ordem única de materiais (D2) — fonte da verdade a partir do schema v2.
  ///
  /// Declarado por último de propósito: o índice de propriedade das colunas
  /// anteriores não muda, então bases já gravadas continuam legíveis.
  /// Vazio em registros anteriores à migração; a leitura em
  /// `PlaylistLocalDatasource` faz a migração lazy
  /// (`items = [...pdfIds, ...audioIds]`) e persiste.
  List<String> items = const [];
}

extension PlaylistSyncStatusX on Playlist {
  PlaylistSyncStatus get syncStatus =>
      PlaylistSyncStatus.values[syncStatusIndex.clamp(
        0,
        PlaylistSyncStatus.values.length - 1,
      )];

  set syncStatus(PlaylistSyncStatus value) => syncStatusIndex = value.index;

  PlaylistReach? get publicationReach {
    final index = publicationReachIndex;
    if (index == null) return null;
    if (index < 0 || index >= PlaylistReach.values.length) return null;
    return PlaylistReach.values[index];
  }

  set publicationReach(PlaylistReach? value) =>
      publicationReachIndex = value?.index;

  PlaylistCategory? get publicationCategory {
    final index = publicationCategoryIndex;
    if (index == null) return null;
    if (index < 0 || index >= PlaylistCategory.values.length) return null;
    return PlaylistCategory.values[index];
  }

  set publicationCategory(PlaylistCategory? value) =>
      publicationCategoryIndex = value?.index;
}
