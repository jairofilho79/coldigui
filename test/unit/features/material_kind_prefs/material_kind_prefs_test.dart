import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 12, 10);

  test('validated aceita até 5 ids únicos e preserva a ordem', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['a', 'b', 'c', 'd', 'e'],
      updatedAt: at,
    );
    expect(prefs.kindIds, ['a', 'b', 'c', 'd', 'e']);
    expect(prefs.rank, {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4});
    expect(prefs.pendingPush, isFalse);
  });

  test('validated rejeita 6 ids, duplicata e id vazio', () {
    expect(
      () => MaterialKindPrefs.validated(
        kindIds: const ['1', '2', '3', '4', '5', '6'],
        updatedAt: at,
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          MaterialKindPrefs.validated(kindIds: const ['a', 'a'], updatedAt: at),
      throwsArgumentError,
    );
    expect(
      () =>
          MaterialKindPrefs.validated(kindIds: const ['a', ''], updatedAt: at),
      throwsArgumentError,
    );
  });

  test('round-trip JSON com pendingPush e updatedAt em UTC', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['x'],
      updatedAt: at,
      pendingPush: true,
    );
    final restored = MaterialKindPrefs.fromJson(prefs.toJson());
    expect(restored, isNotNull);
    expect(restored!.kindIds, ['x']);
    expect(restored.updatedAt, at);
    expect(restored.pendingPush, isTrue);
  });

  test('fromJson tolera lixo: null, sem kindIds, data inválida', () {
    expect(MaterialKindPrefs.fromJson(null), isNull);
    expect(
      MaterialKindPrefs.fromJson({'updatedAt': '2026-01-01T00:00:00Z'}),
      isNull,
    );
    expect(
      MaterialKindPrefs.fromJson({
        'kindIds': ['a'],
        'updatedAt': 'ontem',
      }),
      isNull,
    );
    // Mais de 5 ids ou duplicatas gravados por outra versão: corta em vez de
    // recusar o documento inteiro.
    final over = MaterialKindPrefs.fromJson({
      'kindIds': ['1', '2', '2', '3', '4', '5', '6'],
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });
    expect(over!.kindIds, ['1', '2', '3', '4', '5']);
  });

  test('empty não tem ids, rank vazio e updatedAt na época', () {
    expect(MaterialKindPrefs.empty.kindIds, isEmpty);
    expect(MaterialKindPrefs.empty.rank, isEmpty);
    expect(MaterialKindPrefs.empty.updatedAt.millisecondsSinceEpoch, 0);
    expect(MaterialKindPrefs.empty.preferredTypeByKind, isEmpty);
  });

  test('validated sem preferredTypeByKind vira mapa vazio', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['a'],
      updatedAt: at,
    );
    expect(prefs.preferredTypeByKind, isEmpty);
  });

  test('validated preserva o material type preferido por kind', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['a', 'b'],
      updatedAt: at,
      preferredTypeByKind: const {'a': 'chord'},
    );
    expect(prefs.preferredTypeByKind, {'a': 'chord'});
  });

  test('copyWith troca só o preferredTypeByKind quando informado', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['a'],
      updatedAt: at,
      preferredTypeByKind: const {'a': 'pdf'},
    );
    final updated = prefs.copyWith(preferredTypeByKind: const {'a': 'chord'});
    expect(updated.preferredTypeByKind, {'a': 'chord'});
    expect(updated.kindIds, ['a']);
  });

  test('round-trip JSON preserva preferredTypeByKind', () {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['x'],
      updatedAt: at,
      preferredTypeByKind: const {'x': 'chord'},
    );
    final restored = MaterialKindPrefs.fromJson(prefs.toJson());
    expect(restored!.preferredTypeByKind, {'x': 'chord'});
  });

  test(
    'fromJson sem preferredTypeByKind vira mapa vazio (documento antigo)',
    () {
      final restored = MaterialKindPrefs.fromJson({
        'kindIds': ['a'],
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(restored!.preferredTypeByKind, isEmpty);
    },
  );
}
