import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_reader_viewport_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfReaderViewportPolicy', () {
    test('agenda refresh só na primeira vez por página', () {
      final policy = PdfReaderViewportPolicy(initialPage: 1);

      expect(policy.shouldScheduleRefresh(2), isTrue);
      expect(policy.shouldScheduleRefresh(2), isFalse);
      expect(policy.shouldScheduleRefresh(3), isTrue);
    });

    test('não agenda refresh para a página inicial já registrada', () {
      final policy = PdfReaderViewportPolicy(initialPage: 1);

      expect(policy.shouldScheduleRefresh(1), isFalse);
      expect(policy.shouldScheduleRefresh(2), isTrue);
    });
  });

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
