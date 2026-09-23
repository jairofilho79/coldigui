import 'package:coldigui/features/catalog/presentation/providers/known_praise_ids_provider.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('são os catalogIds do índice, inclusive praises fora da busca', () {
    final container = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(
          ColdigomSearchIndex.build(const [], catalogIds: {'p-index', 'p-yt'}),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(knownPraiseIdsProvider), {'p-index', 'p-yt'});
  });
}
