import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_page_exception.dart';
import 'package:coldigui/features/pdf_reader/domain/ports/pdf_reader_controller_port.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/navigate_pdf_pages.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController implements PdfReaderControllerPort {
  @override
  int? currentPage = 2;
  @override
  int? pagesCount = 5;
  int? lastGoToPage;
  int nextCalls = 0;
  int previousCalls = 0;

  @override
  Future<void> applyFitMode(PdfFitMode mode) async {}

  @override
  Future<void> goToPage(int pageNumber) async {
    lastGoToPage = pageNumber;
  }

  @override
  Future<void> nextPage() async {
    nextCalls++;
    currentPage = (currentPage ?? 1) + 1;
  }

  @override
  Future<void> previousPage() async {
    previousCalls++;
    currentPage = (currentPage ?? 1) - 1;
  }
}

void main() {
  late _FakeController controller;
  late NavigatePdfPages useCase;

  setUp(() {
    controller = _FakeController();
    useCase = NavigatePdfPages(controller);
  });

  test('call navega para página válida', () async {
    await useCase.call(targetPage: 3, pagesCount: 5);
    expect(controller.lastGoToPage, 3);
  });

  test('call rejeita página abaixo de 1', () async {
    await expectLater(
      useCase.call(targetPage: 0, pagesCount: 5),
      throwsA(isA<InvalidPdfPageException>()),
    );
  });

  test('call rejeita página acima do total', () async {
    await expectLater(
      useCase.call(targetPage: 6, pagesCount: 5),
      throwsA(isA<InvalidPdfPageException>()),
    );
  });

  test('call rejeita documento sem páginas', () async {
    await expectLater(
      useCase.call(targetPage: 1, pagesCount: 0),
      throwsA(isA<InvalidPdfPageException>()),
    );
  });

  test('nextPage avança quando não está na última', () async {
    controller.currentPage = 2;
    await useCase.nextPage(pagesCount: 5);
    expect(controller.nextCalls, 1);
  });

  test('nextPage não avança na última página', () async {
    controller.currentPage = 5;
    await useCase.nextPage(pagesCount: 5);
    expect(controller.nextCalls, 0);
  });

  test('previousPage volta quando não está na primeira', () async {
    controller.currentPage = 3;
    await useCase.previousPage();
    expect(controller.previousCalls, 1);
  });

  test('previousPage não volta na primeira página', () async {
    controller.currentPage = 1;
    await useCase.previousPage();
    expect(controller.previousCalls, 0);
  });
}
