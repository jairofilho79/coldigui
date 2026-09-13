import 'package:coldigui/features/material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Item = ({String id, String? kind});

_Item _i(String id, [String? kind]) => (id: id, kind: kind);

void main() {
  final items = <_Item>[
    _i('1', 'coro'),
    _i('2'),
    _i('3', 'soprano'),
    _i('4', 'coro'),
    _i('5', 'tenor'),
  ];

  test('rank vazio devolve a própria lista, na mesma ordem', () {
    final out = orderByFavoriteKinds(items, const {}, kindIdOf: (i) => i.kind);
    expect(identical(out, items), isTrue);
  });

  test('favoritos sobem na ordem do rank; o resto mantém a ordem original', () {
    final out = orderByFavoriteKinds(items, const {
      'soprano': 0,
      'coro': 1,
    }, kindIdOf: (i) => i.kind);
    expect(out.map((i) => i.id), ['3', '1', '4', '2', '5']);
  });

  test('é estável entre itens do mesmo kind favorito', () {
    final out = orderByFavoriteKinds(
      [_i('b', 'x'), _i('a', 'x'), _i('c', 'y')],
      const {'x': 0},
      kindIdOf: (i) => i.kind,
    );
    expect(out.map((i) => i.id), ['b', 'a', 'c']);
  });

  test('kind null nunca sobe', () {
    final out = orderByFavoriteKinds(
      [_i('n'), _i('f', 'fav')],
      const {'fav': 0},
      kindIdOf: (i) => i.kind,
    );
    expect(out.map((i) => i.id), ['f', 'n']);
  });

  test('não muta a lista de entrada', () {
    final input = [_i('a', 'z'), _i('b', 'fav')];
    orderByFavoriteKinds(input, const {'fav': 0}, kindIdOf: (i) => i.kind);
    expect(input.map((i) => i.id), ['a', 'b']);
  });
}
