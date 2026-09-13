import 'dart:io';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('pdf_view_params_');
    // O PdfViewer chama pdfrxFlutterInitialize, que pede o diretório de cache
    // ao path_provider — mesmo mock do pdfrx_viewer_adapter_test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  testWidgets(
    'PdfReaderPdfView entrega ao PdfViewer os params do leitor com a física da plataforma',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final handle = createTrackableHandle(pageCount: 2);
      addTearDown(handle.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: PdfReaderPdfView(
                handle: handle,
                navigateToPage: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
      final params = viewer.params;
      expect(params.textSelectionParams?.enabled, isFalse);
      expect(params.pageDropShadow, isNull);
      expect(params.sizeDelegateProvider, kPdfReaderSizeDelegateProvider);
      expect(params.scrollPhysics, isNotNull);
      expect(
        params.interactionDelegateProvider,
        isA<PdfViewerScrollInteractionDelegateProviderPhysics>(),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
