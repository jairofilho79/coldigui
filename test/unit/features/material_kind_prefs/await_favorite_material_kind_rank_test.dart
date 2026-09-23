import 'dart:async';

import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_kind_prefs_test_helpers.dart';

class _HangingPrefs extends MaterialKindPrefsNotifier {
  @override
  Future<MaterialKindPrefs> build() => Completer<MaterialKindPrefs>().future;
}

class _FailingPrefs extends MaterialKindPrefsNotifier {
  @override
  Future<MaterialKindPrefs> build() async =>
      throw StateError('prefs quebradas');
}

/// Dá um `Ref` estável ao helper — um `Provider` sem `watch` não reconstrói.
final _rankProbe =
    Provider<Future<Map<String, int>> Function(Duration timeout)>(
      (ref) =>
          (timeout) => awaitFavoriteMaterialKindRank(ref, timeout: timeout),
    );

void main() {
  Future<Map<String, int>> rankWith(
    MaterialKindPrefsNotifier Function() create, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    final c = ProviderContainer(
      overrides: [materialKindPrefsProvider.overrideWith(create)],
    );
    addTearDown(c.dispose);
    return c.read(_rankProbe)(timeout);
  }

  test('logado com favoritos → rank na ordem', () async {
    final prefs = MaterialKindPrefs.validated(
      kindIds: const ['k-audio', 'k-part'],
      updatedAt: DateTime.utc(2026, 9, 23),
    );
    expect(await rankWith(() => FixedMaterialKindPrefsNotifier(prefs)), {
      'k-audio': 0,
      'k-part': 1,
    });
  });

  test('deslogado → vazio', () async {
    expect(
      await rankWith(
        () => FixedMaterialKindPrefsNotifier(MaterialKindPrefs.empty),
      ),
      isEmpty,
    );
  });

  test('favoritos que não chegam no prazo → vazio', () async {
    expect(
      await rankWith(
        _HangingPrefs.new,
        timeout: const Duration(milliseconds: 50),
      ),
      isEmpty,
    );
  });

  test('erro ao ler favoritos → vazio', () async {
    expect(await rankWith(_FailingPrefs.new), isEmpty);
  });
}
