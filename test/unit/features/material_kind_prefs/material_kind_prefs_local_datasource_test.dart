import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
