import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_remote_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/domain/repositories/material_kind_prefs_repository.dart';
import 'package:coldigui/features/material_kind_prefs/domain/usecases/sync_material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements MaterialKindPrefsRepository {
  final map = <String, MaterialKindPrefs>{};

  @override
  Future<MaterialKindPrefs?> read(String sub) async => map[sub];

  @override
  Future<void> write(String sub, MaterialKindPrefs prefs) async =>
      map[sub] = prefs;
}

MaterialKindPrefs _doc(List<String> ids, int day, {bool pending = false}) =>
    MaterialKindPrefs.validated(
      kindIds: ids,
      updatedAt: DateTime.utc(2026, 9, day),
      pendingPush: pending,
    );

void main() {
  late _MemoryRepository repo;
  final putCalls = <MaterialKindPrefs>[];

  setUp(() {
    repo = _MemoryRepository();
    putCalls.clear();
  });

  SyncMaterialKindPrefs make({
    MaterialKindPrefs? remote,
    Object? fetchError,
    Object? putError,
  }) {
    return SyncMaterialKindPrefs(
      repo,
      (_) async {
        if (fetchError != null) throw fetchError;
        return remote;
      },
      ({required idToken, required prefs}) async {
        putCalls.add(prefs);
        if (putError != null) throw putError;
        return prefs.copyWith(pendingPush: false);
      },
    );
  }

  test('sem token: skipped, sem tocar nada', () async {
    final result = await make()(idToken: null, sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.skipped);
    expect(putCalls, isEmpty);
  });

  test('remoto mais novo é adotado (pulled)', () async {
    repo.map['s'] = _doc(['local'], 1, pending: true);
    final result = await make(remote: _doc(['remoto'], 5))(
      idToken: 't',
      sub: 's',
    );
    expect(result.outcome, MaterialKindPrefsSyncOutcome.pulled);
    expect(repo.map['s']!.kindIds, ['remoto']);
    expect(repo.map['s']!.pendingPush, isFalse);
    expect(putCalls, isEmpty);
  });

  test('sem local e com remoto: adota (pulled)', () async {
    final result = await make(remote: _doc(['remoto'], 5))(
      idToken: 't',
      sub: 's',
    );
    expect(result.outcome, MaterialKindPrefsSyncOutcome.pulled);
    expect(repo.map['s']!.kindIds, ['remoto']);
  });

  test(
    'local pendente e mais novo faz PUT (pushed) e limpa pendingPush',
    () async {
      repo.map['s'] = _doc(['local'], 9, pending: true);
      final result = await make(remote: _doc(['remoto'], 5))(
        idToken: 't',
        sub: 's',
      );
      expect(result.outcome, MaterialKindPrefsSyncOutcome.pushed);
      expect(putCalls.single.kindIds, ['local']);
      expect(repo.map['s']!.pendingPush, isFalse);
    },
  );

  test('409 no PUT adota o remoto (conflictAdopted)', () async {
    repo.map['s'] = _doc(['local'], 9, pending: true);
    final result = await make(
      remote: null,
      putError: MaterialKindPrefsConflict(_doc(['ganhou'], 10)),
    )(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.conflictAdopted);
    expect(repo.map['s']!.kindIds, ['ganhou']);
    expect(repo.map['s']!.pendingPush, isFalse);
  });

  test(
    'pull falha mas push pendente segue; pullError fica no resultado',
    () async {
      repo.map['s'] = _doc(['local'], 9, pending: true);
      final result = await make(fetchError: StateError('rede'))(
        idToken: 't',
        sub: 's',
      );
      expect(result.outcome, MaterialKindPrefsSyncOutcome.pushed);
      expect(result.pullError, isA<StateError>());
      expect(result.error, isA<StateError>());
    },
  );

  test(
    'push falha por rede: local continua pendente, pushError no resultado',
    () async {
      repo.map['s'] = _doc(['local'], 9, pending: true);
      final result = await make(putError: StateError('rede'))(
        idToken: 't',
        sub: 's',
      );
      expect(result.outcome, MaterialKindPrefsSyncOutcome.noop);
      expect(result.pushError, isA<StateError>());
      expect(repo.map['s']!.pendingPush, isTrue);
    },
  );

  test('nada pendente e remoto igual ou mais velho: noop', () async {
    repo.map['s'] = _doc(['local'], 9);
    final result = await make(remote: _doc(['local'], 9))(
      idToken: 't',
      sub: 's',
    );
    expect(result.outcome, MaterialKindPrefsSyncOutcome.noop);
    expect(result.changedLocal, isFalse);
    expect(putCalls, isEmpty);
  });

  test('sem local nem remoto: noop', () async {
    final result = await make(remote: null)(idToken: 't', sub: 's');
    expect(result.outcome, MaterialKindPrefsSyncOutcome.noop);
    expect(repo.map, isEmpty);
  });
}
