import 'dart:io';

import 'package:coldigui/core/database/collections/audio_flag.dart';
import 'package:coldigui/core/database/collections/playlist_sync_status.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/audio_flags/data/datasources/audio_flag_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// Dono por conta (spec A.5) contra um Isar de verdade.
///
/// Os testes do caso de uso usam um repositório de memória que **reimplementa**
/// as regras; aqui quem responde é a consulta Isar que roda em produção.
void main() {
  late Directory tempDir;
  late Isar isar;
  late AudioFlagLocalDatasource datasource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_flag_owner_');
    isar = Isar.open(schemas: [AudioFlagSchema], directory: tempDir.path);
    datasource = AudioFlagLocalDatasource(isar);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seed({
    required String flagId,
    String? ownerSub,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
    DateTime? deletedAt,
    String audioId = 'aud-1',
  }) {
    final row = AudioFlag()
      ..flagId = flagId
      ..audioId = audioId
      ..positionMs = 1000
      ..label = flagId
      ..createdAt = DateTime.utc(2026, 1, 1)
      ..updatedAt = DateTime.utc(2026, 2, 1)
      ..version = 1
      ..syncStatus = syncStatus
      ..deletedAt = deletedAt
      ..ownerSub = ownerSub;
    return datasource.insert(row);
  }

  /// `flagId` de tudo que sobrou no banco, ordenado para comparar sem depender
  /// da ordem de varredura do Isar.
  List<String> survivors() =>
      isar.audioFlags.where().findAll().map((r) => r.flagId).toList()..sort();

  AudioFlag? row(String flagId) =>
      isar.audioFlags.where().flagIdEqualTo(flagId).findFirst();

  group('purgeSyncedOwnedBy', () {
    test('apaga só as synced do dono anterior', () async {
      await seed(flagId: 'a-synced', ownerSub: 'sub-a');
      await seed(flagId: 'a-synced-2', ownerSub: 'sub-a');
      await seed(
        flagId: 'a-pending',
        ownerSub: 'sub-a',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );
      await seed(
        flagId: 'a-conflict',
        ownerSub: 'sub-a',
        syncStatus: PlaylistSyncStatus.conflict,
      );
      await seed(flagId: 'b-synced', ownerSub: 'sub-b');
      await seed(flagId: 'sem-dono');

      final purged = await datasource.purgeSyncedOwnedBy('sub-a');

      expect(purged, 2);
      expect(survivors(), ['a-conflict', 'a-pending', 'b-synced', 'sem-dono']);
    });

    test('poupa as pendentes e em conflito do dono anterior', () async {
      await seed(
        flagId: 'a-pending',
        ownerSub: 'sub-a',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );
      await seed(
        flagId: 'a-conflict',
        ownerSub: 'sub-a',
        syncStatus: PlaylistSyncStatus.conflict,
      );

      expect(await datasource.purgeSyncedOwnedBy('sub-a'), 0);
      expect(survivors(), ['a-conflict', 'a-pending']);
      // O dono antigo fica na linha: ela não entra no push da conta nova.
      expect(row('a-pending')?.ownerSub, 'sub-a');
    });

    test('não encosta em linha de outro dono nem nas sem dono', () async {
      await seed(flagId: 'b-synced', ownerSub: 'sub-b');
      await seed(flagId: 'sem-dono');

      expect(await datasource.purgeSyncedOwnedBy('sub-a'), 0);
      expect(survivors(), ['b-synced', 'sem-dono']);
    });

    test('apaga também o tombstone synced do dono anterior', () async {
      await seed(
        flagId: 'a-tombstone',
        ownerSub: 'sub-a',
        deletedAt: DateTime.utc(2026, 6, 1),
      );

      expect(await datasource.purgeSyncedOwnedBy('sub-a'), 1);
      expect(survivors(), isEmpty);
    });
  });

  group('adoptForSub', () {
    test('adota as sem dono e as já do sub, pulando as de outro', () async {
      await seed(flagId: 'sem-dono');
      await seed(flagId: 'minha', ownerSub: 'sub-1');
      await seed(flagId: 'alheia', ownerSub: 'sub-2');

      await datasource.adoptForSub('sub-1');

      expect(row('sem-dono')?.ownerSub, 'sub-1');
      expect(row('sem-dono')?.syncStatus, PlaylistSyncStatus.pendingPush);
      expect(row('minha')?.ownerSub, 'sub-1');
      expect(row('minha')?.syncStatus, PlaylistSyncStatus.pendingPush);

      // A de outra conta fica intocada nos dois campos.
      expect(row('alheia')?.ownerSub, 'sub-2');
      expect(row('alheia')?.syncStatus, PlaylistSyncStatus.synced);
    });

    test('não ressuscita tombstone', () async {
      await seed(flagId: 'morta', deletedAt: DateTime.utc(2026, 6, 1));

      await datasource.adoptForSub('sub-1');

      expect(row('morta')?.ownerSub, isNull);
      expect(row('morta')?.deletedAt, isNotNull);
    });

    test('preserva o resto da linha', () async {
      await seed(flagId: 'f1', audioId: 'aud-9');

      await datasource.adoptForSub('sub-1');

      final adopted = row('f1');
      expect(adopted?.audioId, 'aud-9');
      expect(adopted?.positionMs, 1000);
      expect(adopted?.label, 'f1');
      expect(adopted?.version, 1);
      // O Isar devolve `DateTime` em hora local — mesmo instante, `isUtc`
      // falso. Comparar por instante é o que vale: as regras de LWW do sync
      // usam `isBefore`/`isAfter`/`isAtSameMomentAs`, que ignoram o fuso.
      expect(
        adopted?.updatedAt.toUtc(),
        DateTime.utc(2026, 2, 1),
        reason: 'a adoção não pode mexer na chave de last-write-wins',
      );
    });
  });

  group('findPendingPush', () {
    test('entrega as do sub e as sem dono, nunca as de outro', () async {
      await seed(
        flagId: 'minha',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );
      await seed(flagId: 'orfa', syncStatus: PlaylistSyncStatus.pendingPush);
      await seed(
        flagId: 'alheia',
        ownerSub: 'sub-2',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );

      final pending = await datasource.findPendingPush(sub: 'sub-1');

      expect(pending.map((r) => r.flagId).toList()..sort(), ['minha', 'orfa']);
    });

    test('sem sub só as órfãs entram', () async {
      await seed(flagId: 'orfa', syncStatus: PlaylistSyncStatus.pendingPush);
      await seed(
        flagId: 'minha',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );

      final pending = await datasource.findPendingPush();

      expect(pending.map((r) => r.flagId), ['orfa']);
    });

    test('ignora synced e tombstone do próprio dono', () async {
      await seed(flagId: 'synced', ownerSub: 'sub-1');
      await seed(
        flagId: 'tombstone',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: DateTime.utc(2026, 6, 1),
      );
      await seed(
        flagId: 'pendente',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );

      final pending = await datasource.findPendingPush(sub: 'sub-1');

      expect(pending.map((r) => r.flagId), ['pendente']);
    });
  });

  group('findTombstones', () {
    test('entrega os do sub e os sem dono, nunca os de outro', () async {
      final gone = DateTime.utc(2026, 6, 1);
      await seed(
        flagId: 'minha',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: gone,
      );
      await seed(
        flagId: 'orfa',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: gone,
      );
      await seed(
        flagId: 'alheia',
        ownerSub: 'sub-2',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: gone,
      );

      final tombstones = await datasource.findTombstones(sub: 'sub-1');

      // O tombstone da outra conta fica no aparelho até ela voltar: mandar o
      // DELETE dele com o token desta conta dá 404 e acende a linha de erro do
      // player a cada boot.
      expect(tombstones.map((r) => r.flagId).toList()..sort(), [
        'minha',
        'orfa',
      ]);
    });

    test('sem sub só os órfãos entram', () async {
      final gone = DateTime.utc(2026, 6, 1);
      await seed(
        flagId: 'orfa',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: gone,
      );
      await seed(
        flagId: 'minha',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: gone,
      );

      final tombstones = await datasource.findTombstones();

      expect(tombstones.map((r) => r.flagId), ['orfa']);
    });

    test('ignora linha viva e tombstone já synced do próprio dono', () async {
      await seed(
        flagId: 'viva',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
      );
      await seed(
        flagId: 'ja-apagada',
        ownerSub: 'sub-1',
        deletedAt: DateTime.utc(2026, 6, 1),
      );
      await seed(
        flagId: 'pendente',
        ownerSub: 'sub-1',
        syncStatus: PlaylistSyncStatus.pendingPush,
        deletedAt: DateTime.utc(2026, 6, 1),
      );

      final tombstones = await datasource.findTombstones(sub: 'sub-1');

      expect(tombstones.map((r) => r.flagId), ['pendente']);
    });
  });

  group('Isar indisponível', () {
    // Sem banco, a adoção e a purga **não podem** fingir sucesso: o notifier
    // persistiria o `sub` como adotado e o próximo boot não repetiria a
    // adoção — as linhas ficariam sem dono e sem subir para sempre.
    const unavailable = AudioFlagLocalDatasource.unavailable();

    test('adoptForSub lança StorageUnavailableException', () async {
      await expectLater(
        unavailable.adoptForSub('sub-1'),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'audioFlags.adoptForSub',
          ),
        ),
      );
    });

    test('purgeSyncedOwnedBy lança StorageUnavailableException', () async {
      await expectLater(
        unavailable.purgeSyncedOwnedBy('sub-1'),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'audioFlags.purgeSyncedOwnedBy',
          ),
        ),
      );
    });

    test('as leituras seguem devolvendo vazio', () async {
      expect(await unavailable.findTombstones(sub: 'sub-1'), isEmpty);
      expect(await unavailable.findPendingPush(sub: 'sub-1'), isEmpty);
    });
  });

  test('adoção depois da purga deixa só a conta nova pendente', () async {
    // O caminho do notifier na troca de conta, ponta a ponta no banco real.
    await seed(flagId: 'a-synced', ownerSub: 'sub-a');
    await seed(
      flagId: 'a-pending',
      ownerSub: 'sub-a',
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
    await seed(flagId: 'sem-dono');

    await datasource.purgeSyncedOwnedBy('sub-a');
    await datasource.adoptForSub('sub-b');

    // A synced de A saiu; a pendente de A ficou, com o dono antigo, fora do
    // push de B; a órfã foi adotada por B.
    expect(survivors(), ['a-pending', 'sem-dono']);
    expect(row('a-pending')?.ownerSub, 'sub-a');
    expect(row('sem-dono')?.ownerSub, 'sub-b');

    final pending = await datasource.findPendingPush(sub: 'sub-b');
    expect(pending.map((r) => r.flagId), ['sem-dono']);
  });
}
