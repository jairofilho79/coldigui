import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_swipe_policy.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'PdfHorizontalSwipeIndicator mostra chevron direito para próxima',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PdfHorizontalSwipeIndicator(
              direction: PdfPageSwipeDirection.next,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    },
  );

  testWidgets(
    'PdfHorizontalSwipeIndicator mostra chevron esquerdo para anterior',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PdfHorizontalSwipeIndicator(
              direction: PdfPageSwipeDirection.previous,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );
}
