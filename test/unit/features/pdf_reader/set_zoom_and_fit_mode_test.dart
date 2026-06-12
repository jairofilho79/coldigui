import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:coldigui/features/pdf_reader/domain/ports/pdf_reader_controller_port.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/set_zoom_and_fit_mode.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController implements PdfReaderControllerPort {
  PdfFitMode? lastApplied;

  @override
  int? get currentPage => 1;

  @override
  int? get pagesCount => 3;

  @override
  Future<void> applyFitMode(PdfFitMode mode) async {
    lastApplied = mode;
  }

  @override
  Future<void> goToPage(int pageNumber) async {}

  @override
  Future<void> nextPage() async {}

  @override
  Future<void> previousPage() async {}
}

void main() {
  late _FakeController controller;
  late SetZoomAndFitMode useCase;

  setUp(() {
    controller = _FakeController();
    useCase = SetZoomAndFitMode(controller);
  });

  test('call delega page-fit ao adapter', () async {
    await useCase.call(mode: PdfFitMode.pageFit);
    expect(controller.lastApplied, PdfFitMode.pageFit);
  });

  test('call delega page-width ao adapter', () async {
    await useCase.call(mode: PdfFitMode.pageWidth);
    expect(controller.lastApplied, PdfFitMode.pageWidth);
  });
}
