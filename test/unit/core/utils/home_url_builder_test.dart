import 'package:coldigui/core/utils/home_url_builder.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildHomeLocation sem params retorna path base', () {
    expect(buildHomeLocation(), RoutePaths.home);
  });

  test('buildHomeLocation combina pesquisa e filtros', () {
    final location = buildHomeLocation(
      pesquisa: 'aleluia',
      materiais: 'Partitura',
      arranjo: 'ColAdultos',
    );

    expect(location, contains('pesquisa=aleluia'));
    expect(location, contains('materiais=Partitura'));
    expect(location, contains('arranjo=ColAdultos'));
  });

  test('buildHomeLocation codifica valores especiais', () {
    final location = buildHomeLocation(pesquisa: 'são joão');
    expect(location, contains(Uri.encodeComponent('são joão')));
  });
}
