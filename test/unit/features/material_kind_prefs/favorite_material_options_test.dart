import 'dart:convert';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_data_providers.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_favorite_policy.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/coldigom_material_kinds_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/favorite_material_options_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_types_for_kind_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomPraiseCache row(
  List<Map<String, Object?>> materials, {
  String lyrics = '',
}) => ColdigomPraiseCache()
  ..lyrics = lyrics
  ..materialsJson = jsonEncode(materials);

Map<String, Object?> material(String type, String? kind, String name) => {
  'id': '$kind-$type',
  'kind': kind,
  'kindName': name,
  'type': type,
};

class _MemoryCatalog extends ColdigomInMemoryCatalogNotifier {
  _MemoryCatalog(this.rows);
  final List<ColdigomPraiseCache> rows;

  @override
  List<ColdigomPraiseCache> build() => rows;
}

void main() {
  final rows = [
    row([
      material('chord', 'cifra', 'Cifra'),
      material('pdf', 'cifra', 'Cifra'),
      material('pdf', 'cifra', 'Cifra'),
      material('MP3', 'cifra', 'Cifra'),
      material('youtube', 'videos', 'Vídeos'),
      material('audio', 'vozes', 'Vozes'),
      material('gestures', 'gestos', 'Gestos'),
      material('video', 'outro', 'Outro'),
      material('pdf', null, ''),
    ], lyrics: 'Aleluia'),
  ];

  test('oferece todos os formatos não excluídos e deduplica por categoria', () {
    final options = favoriteMaterialOptionsFromCatalog(rows);
    expect(
      options.map((option) => option.id),
      containsAll([
        'cifra',
        'gestos',
        'outro',
        'type:pdf',
        kLyricsFavoriteKindId,
      ]),
    );
    expect(options.map((option) => option.id), isNot(contains('videos')));
    expect(options.map((option) => option.id), isNot(contains('vozes')));
    expect(options.firstWhere((option) => option.id == 'cifra').types, [
      'pdf',
      'chord',
    ]);
    expect(options.firstWhere((option) => option.id == 'outro').types, [
      'video',
    ]);
  });

  test('sem letra no catálogo não inventa uma opção disponível', () {
    final options = favoriteMaterialOptionsFromCatalog([
      row([material('pdf', 'partitura', 'Partitura')]),
    ]);
    expect(
      options.map((option) => option.id),
      isNot(contains(kLyricsFavoriteKindId)),
    );
  });

  test('bloqueio é só áudio/YouTube, incluindo aliases e caixa alta', () {
    for (final type in ['audio', 'mp3', 'M4A', 'wav', 'flac', 'YouTube']) {
      expect(isFavoriteMaterialType(type), isFalse, reason: type);
    }
    for (final type in [
      'pdf',
      'chord',
      'gestures',
      'lyrics',
      'video',
      'novo',
    ]) {
      expect(isFavoriteMaterialType(type), isTrue, reason: type);
    }
  });

  test(
    'providers usam catálogo em memória, sem rede e com os mesmos tipos',
    () async {
      final container = ProviderContainer(
        overrides: [
          coldigomCatalogHydrationProvider.overrideWith(
            (ref) async => ColdigomSearchIndex.empty,
          ),
          coldigomInMemoryCatalogProvider.overrideWith(
            () => _MemoryCatalog(rows),
          ),
          coldigomCatalogLocalDatasourceProvider.overrideWithValue(
            const ColdigomCatalogLocalDatasource.unavailable(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final kinds = await container.read(coldigomMaterialKindsProvider.future);
      expect(kinds.map((kind) => kind.id), contains(kLyricsFavoriteKindId));
      expect(
        await container.read(materialTypesForKindProvider('cifra').future),
        ['pdf', 'chord'],
      );
      expect(
        await container.read(
          materialTypesForKindProvider(kLyricsFavoriteKindId).future,
        ),
        ['lyrics'],
      );
    },
  );

  test(
    'ausência do catálogo é erro explícito, não uma lista de sucesso vazia',
    () async {
      final container = ProviderContainer(
        overrides: [
          coldigomCatalogHydrationProvider.overrideWith(
            (ref) async => ColdigomSearchIndex.empty,
          ),
          coldigomInMemoryCatalogProvider.overrideWith(
            () => _MemoryCatalog([]),
          ),
          coldigomCatalogLocalDatasourceProvider.overrideWithValue(
            const ColdigomCatalogLocalDatasource.unavailable(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(favoriteMaterialOptionsProvider.future),
        throwsStateError,
      );
    },
  );
}
