import '../../../carousel/data/datasources/carousel_local_datasource.dart';
import '../entities/playlist_entry.dart';
import '../repositories/playlist_repository.dart';
import '../utils/playlist_defaults.dart';

/// O que a migração única do carousel Isar fez neste boot.
class MigrationOutcome {
  const MigrationOutcome({this.createdPlaylistId, this.migratedIds = 0});

  /// Id do rascunho criado a partir da coleção antiga, ou `null`.
  final String? createdPlaylistId;

  /// Quantas entradas a coleção `CarouselEntry` tinha.
  final int migratedIds;

  /// `true` quando havia linhas para migrar (e a coleção foi esvaziada).
  bool get didMigrate => migratedIds > 0;
}

/// Migração única da coleção `CarouselEntry` para a lista ativa (D3).
///
/// A seleção deixou de ter persistência própria: o que estava no carousel Isar
/// vira uma lista. Regras:
///
/// - coleção vazia → nada (nem escrita, nem `clear`);
/// - com ids e **sem** lista ativa (ou id órfão) → cria rascunho com os ids
///   classificados pela extensão e devolve o id em [MigrationOutcome];
/// - com ids e **com** lista ativa → a lista vence (o sync era carousel → lista
///   a cada mutação, então as duas já espelhavam);
/// - em todos os casos com ids → esvazia a coleção.
///
/// Sem Isar, [CarouselLocalDatasource.unavailable] devolve `[]` e nada roda —
/// a coleção fica para o próximo boot com storage.
class MigrateCarouselStore {
  const MigrateCarouselStore(this._carousel, this._playlistRepository);

  final CarouselLocalDatasource _carousel;
  final PlaylistRepository _playlistRepository;

  Future<MigrationOutcome> call({required String? activePlaylistId}) async {
    final ids = await _carousel.getOrderedPdfIds();
    if (ids.isEmpty) return const MigrationOutcome();

    final active = activePlaylistId == null
        ? null
        : await _playlistRepository.getById(activePlaylistId);

    String? createdPlaylistId;
    if (active == null) {
      createdPlaylistId = await _playlistRepository.create(
        nome: defaultPlaylistName(),
        entries: ids.map(PlaylistEntry.classified).toList(growable: false),
        salva: false,
      );
    }

    await _carousel.clear();
    return MigrationOutcome(
      createdPlaylistId: createdPlaylistId,
      migratedIds: ids.length,
    );
  }
}
