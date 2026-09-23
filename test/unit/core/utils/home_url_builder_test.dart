import 'package:coldigui/core/utils/home_url_builder.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildHomeLocation sem params retorna path base', () {
    expect(buildHomeLocation(), RoutePaths.home);
  });

  test('buildHomeLocation combina pesquisa e os filtros do catálogo', () {
    final location = buildHomeLocation(
      pesquisa: 'aleluia',
      tonality: 'Dm',
      rhythm: 'Fox',
      category: 'Clamor',
      tags: 'PES',
      materialKinds: 'k1',
    );

    expect(location, contains('pesquisa=aleluia'));
    expect(location, contains('tonality=Dm'));
    expect(location, contains('rhythm=Fox'));
    expect(location, contains('category=Clamor'));
    expect(location, contains('tags=PES'));
    expect(location, contains('materialKinds=k1'));
  });

  test('buildHomeLocation codifica valores especiais', () {
    final location = buildHomeLocation(
      pesquisa: 'são joão',
      tags: 'PES · 9.2026',
    );
    expect(location, contains(Uri.encodeComponent('são joão')));
    expect(location, contains(Uri.encodeComponent('PES · 9.2026')));
  });

  test('link antigo: materiais/arranjo são ignorados', () {
    final uri = Uri.parse(
      '/?pesquisa=x&materiais=Partitura&arranjo=ColAdultos&tags=PES',
    );

    final location = buildHomeLocationFromUri(uri);

    expect(location, buildHomeLocation(pesquisa: 'x', tags: 'PES'));
    expect(location, isNot(contains('materiais')));
    expect(location, isNot(contains('arranjo')));
  });
}
