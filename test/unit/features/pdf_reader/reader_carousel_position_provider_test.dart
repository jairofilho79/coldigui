import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CarouselItem _item(String materialId, int index, {String? key}) {
  return CarouselItem(
    materialId: materialId,
    kind: MaterialKind.pdf,
    index: index,
    key: key ?? materialId,
    numero: '00$index',
    nome: 'Louvor $materialId',
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
  );
}

Future<ProviderContainer> _boot(List<CarouselItem> items) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      carouselItemsProvider.overrideWithValue(items),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('face vazia não tem posição', () async {
    final container = await _boot(const []);

    expect(container.read(readerCarouselPositionProvider('a')), isNull);
  });

  test('posição e vizinhos saem da face de partituras', () async {
    final container = await _boot([
      _item('a', 0),
      _item('b', 1),
      _item('c', 2),
    ]);

    final position = container.read(readerCarouselPositionProvider('b'))!;

    expect(position.currentIndex, 2);
    expect(position.total, 3);
    expect(position.currentKey, 'b');
    expect(position.previousMaterialId, 'a');
    expect(position.nextMaterialId, 'c');
    expect(position.previousKey, 'a');
    expect(position.nextKey, 'c');
    expect(position.canGoPrevious, isTrue);
    expect(position.canGoNext, isTrue);
  });

  test('extremidades não dão a volta', () async {
    final container = await _boot([_item('a', 0), _item('b', 1)]);

    final first = container.read(readerCarouselPositionProvider('a'))!;
    expect(first.previousKey, isNull);
    expect(first.previousMaterialId, isNull);
    expect(first.canGoPrevious, isFalse);

    final last = container.read(readerCarouselPositionProvider('b'))!;
    expect(last.nextKey, isNull);
    expect(last.nextMaterialId, isNull);
    expect(last.canGoNext, isFalse);
  });

  test('posição com louvor repetido usa o item focado', () async {
    final container = await _boot([
      _item('a', 0),
      _item('b', 1),
      _item('a', 2, key: 'a#1'),
    ]);
    container.read(carouselFocusedIndexProvider.notifier).focusKey('a#1');

    final position = container.read(readerCarouselPositionProvider('a'))!;

    expect(position.currentIndex, 3, reason: 'a segunda ocorrência é a focada');
    expect(position.currentKey, 'a#1');
    expect(position.previousKey, 'b');
    expect(position.previousMaterialId, 'b');
    expect(position.nextKey, isNull);
  });

  test('louvor repetido sem foco na ocorrência cai na primeira', () async {
    final container = await _boot([
      _item('a', 0),
      _item('b', 1),
      _item('a', 2, key: 'a#1'),
    ]);
    container.read(carouselFocusedIndexProvider.notifier).focusKey('b');

    final position = container.read(readerCarouselPositionProvider('a'))!;

    expect(position.currentIndex, 1);
    expect(position.currentKey, 'a');
    expect(position.nextKey, 'b');
    expect(position.nextMaterialId, 'b');
  });

  test('id fora da face cai no item focado', () async {
    final container = await _boot([_item('a', 0), _item('b', 1)]);
    container.read(carouselFocusedIndexProvider.notifier).focusKey('b');

    final position = container.read(readerCarouselPositionProvider('zzz'))!;

    expect(position.currentIndex, 2);
    expect(position.currentKey, 'b');
  });
}
