import 'dart:convert';

import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingPreferences extends Fake implements SharedPreferences {
  _FailingPreferences(this.persisted, {required this.throwOnWrite})
    : cached = persisted;

  final String persisted;
  final bool throwOnWrite;
  String cached;

  @override
  String? getString(String key) => cached;

  @override
  Future<bool> setString(String key, String value) async {
    cached = value;
    if (throwOnWrite) throw StateError('storage unavailable');
    return false;
  }

  @override
  Future<void> reload() async => cached = persisted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime.utc(2026, 9, 12);

  test('write/read por sub — outra conta não enxerga', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = MaterialKindPrefsLocalDatasource(prefs);

    await local.write(
      'sub-1',
      MaterialKindPrefs.validated(
        kindIds: const ['a'],
        updatedAt: at,
        pendingPush: true,
      ),
    );

    final mine = local.read('sub-1');
    expect(mine!.kindIds, ['a']);
    expect(mine.pendingPush, isTrue);
    expect(mine.updatedAt, at);
    expect(local.read('sub-2'), isNull);
    expect(
      prefs.getString(MaterialKindPrefsLocalDatasource.keyFor('sub-1')),
      isNotNull,
    );
  });

  test('JSON corrompido lê como null', () async {
    SharedPreferences.setMockInitialValues({
      MaterialKindPrefsLocalDatasource.keyFor('sub-1'): '{nope',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(MaterialKindPrefsLocalDatasource(prefs).read('sub-1'), isNull);
  });

  for (final throwOnWrite in [false, true]) {
    test(
      'gravação falha ($throwOnWrite): propaga e descarta cache não salvo',
      () async {
        final original = MaterialKindPrefs.validated(
          kindIds: const ['type:lyrics'],
          preferredTypeByKind: const {'type:lyrics': 'lyrics'},
          updatedAt: at,
        );
        final prefs = _FailingPreferences(
          jsonEncode(original.toJson()),
          throwOnWrite: throwOnWrite,
        );
        final local = MaterialKindPrefsLocalDatasource(prefs);
        await expectLater(
          local.write('sub-1', original.copyWith(kindIds: ['outro'])),
          throwsStateError,
        );
        expect(local.read('sub-1')!.kindIds, ['type:lyrics']);
        expect(local.read('sub-1')!.preferredTypeByKind, {
          'type:lyrics': 'lyrics',
        });
      },
    );
  }
}
