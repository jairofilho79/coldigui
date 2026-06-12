import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_display_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _itemA = CarouselItem(
  pdfId: 'a',
  sortOrder: 0,
  numero: '001',
  nome: 'A',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
);

const _itemB = CarouselItem(
  pdfId: 'b',
  sortOrder: 1,
  numero: '002',
  nome: 'B',
  categoria: 'Cifra nível I',
  classificacao: 'ColCIAs',
);

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;

  @override
  List<CarouselItem> build() => initial;
}

void main() {
  test('add reflete imediatamente no display', () {
    final container = ProviderContainer(
      overrides: [
        carouselLouvoresProvider.overrideWith(
          () => _FakeCarouselNotifier(const [_itemA]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(carouselLouvoresDisplayProvider)
          .map((e) => e.pdfId)
          .toList(),
      ['a'],
    );

    container.read(carouselLouvoresProvider.notifier).state = [_itemA, _itemB];

    expect(
      container
          .read(carouselLouvoresDisplayProvider)
          .map((e) => e.pdfId)
          .toList(),
      ['a', 'b'],
    );
  });

  test('reorder aguarda debounce antes de atualizar display', () async {
    final container = ProviderContainer(
      overrides: [
        carouselLouvoresProvider.overrideWith(
          () => _FakeCarouselNotifier(const [_itemA, _itemB]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(carouselLouvoresDisplayProvider)
          .map((e) => e.pdfId)
          .toList(),
      ['a', 'b'],
    );

    container.read(carouselLouvoresProvider.notifier).state = [_itemB, _itemA];

    expect(
      container
          .read(carouselLouvoresDisplayProvider)
          .map((e) => e.pdfId)
          .toList(),
      ['a', 'b'],
    );

    await Future<void>.delayed(carouselLouvoresDisplayDebounce);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(
      container
          .read(carouselLouvoresDisplayProvider)
          .map((e) => e.pdfId)
          .toList(),
      ['b', 'a'],
    );
  });
}
