import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/library_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildLibraryLocation sem params retorna path base', () {
    expect(buildLibraryLocation(), RoutePaths.library);
  });

  test('buildLibraryLocation combina filtros do catálogo e vista', () {
    final location = buildLibraryLocation(
      tonality: 'Dm,G',
      rhythm: 'Fox',
      category: 'Clamor',
      tags: 'PES',
      materialKinds: 'k1',
      ordenar: 'nome',
      itensPorPagina: '25',
      pagina: '2',
    );

    expect(location, contains('tonality=${Uri.encodeComponent('Dm,G')}'));
    expect(location, contains('rhythm=Fox'));
    expect(location, contains('category=Clamor'));
    expect(location, contains('tags=PES'));
    expect(location, contains('materialKinds=k1'));
    expect(location, contains('ordenar=nome'));
    expect(location, contains('itensPorPagina=25'));
    expect(location, contains('pagina=2'));
  });

  test('buildLibraryLocation omite defaults', () {
    final location = buildLibraryLocation(
      ordenar: 'numero',
      itensPorPagina: '10',
      pagina: '1',
    );

    expect(location, RoutePaths.library);
  });

  test('buildLibraryLocation codifica valores especiais', () {
    final location = buildLibraryLocation(tags: 'PES · 9.2026');
    expect(location, contains(Uri.encodeComponent('PES · 9.2026')));
  });

  test(
    'link antigo: fonte/materiais/arranjo/arranjoEspecial são ignorados',
    () {
      final uri = Uri.parse(
        '/biblioteca?fonte=coldigom&materiais=Partitura&arranjo=ColAdultos'
        '&arranjoEspecial=Especial&tonality=Dm&pagina=3',
      );

      final location = buildLibraryLocationFromUri(uri);

      expect(location, buildLibraryLocation(tonality: 'Dm', pagina: '3'));
      expect(location, isNot(contains('fonte')));
      expect(location, isNot(contains('materiais')));
      expect(location, isNot(contains('arranjo')));
    },
  );
}
