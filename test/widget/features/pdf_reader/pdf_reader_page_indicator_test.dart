import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

void main() {
  testWidgets('PdfReaderPageIndicator acompanha pageListenable do handle', (
    tester,
  ) async {
    final handle = createTrackableHandle(pageCount: 5);
    handle.loadingState.value = PdfReaderLoadingState.success;
    handle.pageListenable.value = 3;

    final container = ProviderContainer(
      overrides: [
        pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
          (ref) async => PdfReaderSession(
            handle: handle,
            filePath: 'asset:fixtures/sample.pdf',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderPageIndicator(filePath: 'asset:fixtures/sample.pdf'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/5'), findsOneWidget);

    handle.pageListenable.value = 4;
    await tester.pump();

    expect(find.text('4/5'), findsOneWidget);
  });
}
