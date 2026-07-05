import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/domain/repositories/carousel_repository.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/navigate_carousel_in_reader.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCarouselRepository implements CarouselRepository {
  _FakeCarouselRepository(this._orderedPdfIds);

  List<String> _orderedPdfIds;

  @override
  Future<void> add(String pdfId) async {
    if (!_orderedPdfIds.contains(pdfId)) {
      _orderedPdfIds = [..._orderedPdfIds, pdfId];
    }
  }

  @override
  Future<void> clear() async {
    _orderedPdfIds = [];
  }

  @override
  Future<List<CarouselItem>> getOrderedItems({
    required Map<String, CarouselItemMetadata> pdfIdToMetadata,
  }) async {
    return [
      for (var i = 0; i < _orderedPdfIds.length; i++)
        CarouselItem(
          pdfId: _orderedPdfIds[i],
          sortOrder: i,
          numero: '',
          nome: pdfIdToMetadata[_orderedPdfIds[i]]?.nome ?? _orderedPdfIds[i],
          categoria: pdfIdToMetadata[_orderedPdfIds[i]]?.categoria ?? '',
          classificacao:
              pdfIdToMetadata[_orderedPdfIds[i]]?.classificacao ?? '',
        ),
    ];
  }

  @override
  Future<List<String>> getOrderedPdfIds() async =>
      List.unmodifiable(_orderedPdfIds);

  @override
  Future<void> remove(String pdfId) async {
    _orderedPdfIds = _orderedPdfIds.where((id) => id != pdfId).toList();
  }

  @override
  Future<bool> replacePdfId(String oldPdfId, String newPdfId) async {
    if (oldPdfId == newPdfId) return false;
    final index = _orderedPdfIds.indexOf(oldPdfId);
    if (index < 0) return false;
    if (_orderedPdfIds.contains(newPdfId)) {
      _orderedPdfIds = _orderedPdfIds.where((id) => id != oldPdfId).toList();
      return true;
    }
    _orderedPdfIds = [
      for (var i = 0; i < _orderedPdfIds.length; i++)
        if (i == index) newPdfId else _orderedPdfIds[i],
    ];
    return true;
  }

  @override
  Future<void> reorder(List<String> orderedPdfIds) async {
    _orderedPdfIds = List.of(orderedPdfIds);
  }

  @override
  Future<void> replaceAll(List<String> orderedPdfIds) async {
    _orderedPdfIds = List.of(orderedPdfIds);
  }
}

void main() {
  late NavigateCarouselInReader useCase;

  test('getPosition retorna null quando carousel vazio', () async {
    useCase = NavigateCarouselInReader(_FakeCarouselRepository([]));

    final position = await useCase.getPosition(currentPdfId: 'A');

    expect(position, isNull);
  });

  test('getPosition retorna null quando pdfId fora da seleção', () async {
    useCase = NavigateCarouselInReader(_FakeCarouselRepository(['A', 'B']));

    final position = await useCase.getPosition(currentPdfId: 'Z');

    expect(position, isNull);
  });

  test('getPosition retorna índice central com prev/next', () async {
    useCase = NavigateCarouselInReader(
      _FakeCarouselRepository(['A', 'B', 'C']),
    );

    final position = await useCase.getPosition(currentPdfId: 'B');

    expect(position?.currentIndex, 2);
    expect(position?.total, 3);
    expect(position?.previousPdfId, 'A');
    expect(position?.nextPdfId, 'C');
  });

  test('getPosition sem wrap no primeiro item', () async {
    useCase = NavigateCarouselInReader(
      _FakeCarouselRepository(['A', 'B', 'C']),
    );

    final position = await useCase.getPosition(currentPdfId: 'A');

    expect(position?.previousPdfId, isNull);
    expect(position?.nextPdfId, 'B');
    expect(position?.canGoPrevious, isFalse);
    expect(position?.canGoNext, isTrue);
  });

  test('getPosition sem wrap no último item', () async {
    useCase = NavigateCarouselInReader(
      _FakeCarouselRepository(['A', 'B', 'C']),
    );

    final position = await useCase.getPosition(currentPdfId: 'C');

    expect(position?.previousPdfId, 'B');
    expect(position?.nextPdfId, isNull);
    expect(position?.canGoPrevious, isTrue);
    expect(position?.canGoNext, isFalse);
  });

  test('getPosition com um item não permite navegação', () async {
    useCase = NavigateCarouselInReader(_FakeCarouselRepository(['A']));

    final position = await useCase.getPosition(currentPdfId: 'A');

    expect(position?.currentIndex, 1);
    expect(position?.total, 1);
    expect(position?.previousPdfId, isNull);
    expect(position?.nextPdfId, isNull);
    expect(position?.canGoPrevious, isFalse);
    expect(position?.canGoNext, isFalse);
  });

  test('resolveTarget retorna pdfId anterior e próximo', () async {
    useCase = NavigateCarouselInReader(
      _FakeCarouselRepository(['A', 'B', 'C']),
    );

    expect(
      await useCase.resolveTarget(
        currentPdfId: 'B',
        direction: CarouselReaderDirection.previous,
      ),
      'A',
    );
    expect(
      await useCase.resolveTarget(
        currentPdfId: 'B',
        direction: CarouselReaderDirection.next,
      ),
      'C',
    );
  });

  test('resolveTarget retorna null quando pdfId fora da seleção', () async {
    useCase = NavigateCarouselInReader(_FakeCarouselRepository(['A', 'B']));

    final target = await useCase.resolveTarget(
      currentPdfId: 'Z',
      direction: CarouselReaderDirection.next,
    );

    expect(target, isNull);
  });

  test('resolveTarget retorna null na extremidade sem wrap', () async {
    useCase = NavigateCarouselInReader(_FakeCarouselRepository(['A', 'B']));

    expect(
      await useCase.resolveTarget(
        currentPdfId: 'A',
        direction: CarouselReaderDirection.previous,
      ),
      isNull,
    );
    expect(
      await useCase.resolveTarget(
        currentPdfId: 'B',
        direction: CarouselReaderDirection.next,
      ),
      isNull,
    );
  });
}
