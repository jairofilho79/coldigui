import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _lyrics = LyricsMaterial(
  praiseId: 'p1',
  nome: 'Ainda há tempo',
  numero: '001',
);

void main() {
  test('mergeCatalog escreve os sete caches de uma vez', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(coldigomCacheWriterProvider)
        .mergeCatalog(
          louvores: const [],
          audioTracks: const [],
          chordMaterials: const [],
          gestureMaterials: const [],
          youtubeMaterials: const [],
          lyrics: const [_lyrics],
          metaByGroupId: const {
            'p1': ColdigomPraiseMetadata(name: 'Ainda há tempo'),
          },
        );

    expect(container.read(coldigomLyricsCacheProvider)['p1'], same(_lyrics));
    expect(
      container.read(coldigomPraiseMetaCacheProvider)['p1']!.name,
      'Ainda há tempo',
    );
  });

  test('a fonte monta o grupo só com a letra e resolve o id lyrics:', () {
    const source = ColdigomCatalogSource(
      lyrics: {'p1': _lyrics},
      praiseMeta: {'p1': ColdigomPraiseMetadata(name: 'Ainda há tempo')},
    );

    final group = source.findGroupById('p1')!;
    expect(group.lyrics, same(_lyrics));
    expect(group.nome, 'Ainda há tempo');
    expect(group.coldigomMeta, isNotNull);
    expect(source.findMaterialById('lyrics:p1'), same(_lyrics));
    expect(source.findMaterialById('lyrics:zz'), isNull);
    expect(source.findGroupForMaterial('lyrics:p1')!.groupId, 'p1');
  });

  test('o provider da fonte observa o cache de letras', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(coldigomCacheWriterProvider).mergeLyrics(const [_lyrics]);

    expect(
      container
          .read(coldigomCatalogSourceProvider)
          .findMaterialById('lyrics:p1'),
      same(_lyrics),
    );
  });
}
