import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfReattachGuard', () {
    test('permite apenas um agendamento até complete', () {
      final guard = PdfReattachGuard();

      expect(guard.trySchedule(), isTrue);
      expect(guard.trySchedule(), isFalse);

      guard.complete();
      expect(guard.trySchedule(), isTrue);
    });
  });
}
