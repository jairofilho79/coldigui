import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/library_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildLibraryLocation sem params retorna path base', () {
    expect(buildLibraryLocation(), RoutePaths.library);
  });

  test('buildLibraryLocation combina filtros e paginação', () {
    final location = buildLibraryLocation(
      materiais: 'Partitura',
      arranjo: 'ColAdultos',
      arranjoEspecial: 'Especial',
      ordenar: 'nome',
      itensPorPagina: '25',
      pagina: '2',
    );

    expect(location, contains('materiais=Partitura'));
    expect(location, contains('arranjo=ColAdultos'));
    expect(location, contains('arranjoEspecial=Especial'));
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
    final location = buildLibraryLocation(arranjoEspecial: 'são especial');
    expect(location, contains(Uri.encodeComponent('são especial')));
  });

  test('buildLibraryLocationFromUri normaliza uri', () {
    final uri = Uri.parse(
      '/biblioteca?ordenar=nome&pagina=2&materiais=Partitura',
    );

    expect(
      buildLibraryLocationFromUri(uri),
      buildLibraryLocation(
        materiais: 'Partitura',
        ordenar: 'nome',
        pagina: '2',
      ),
    );
  });
}
