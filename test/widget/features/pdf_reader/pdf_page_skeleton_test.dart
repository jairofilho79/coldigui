import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_page_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

class _FixedOfflineCacheStatusNotifier extends OfflineCacheStatusNotifier {
  @override
  OfflineCacheStatus build() => OfflineCacheStatus.empty;
}

ProviderScope _readerScope({
  required SharedPreferences prefs,
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      offlineCacheStatusProvider.overrideWith(
        _FixedOfflineCacheStatusNotifier.new,
      ),
      carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
      ...overrides,
    ],
    child: child,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PdfPageSkeleton mantém proporção A4', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PdfPageSkeleton())),
    );

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(
      aspectRatio.aspectRatio,
      closeTo(PdfPageSkeleton.a4AspectRatio, 0.001),
    );
  });

  testWidgets('PdfReaderScreen exibe skeleton e título durante loading', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCompleter = Completer<PdfReaderSession>();

    addTearDown(() {
      if (!sessionCompleter.isCompleted) {
        sessionCompleter.completeError(StateError('test ended'));
      }
    });

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider(
            'asset:fixtures/sample.pdf',
          ).overrideWith((ref) => sessionCompleter.future),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Meu Louvor',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(PdfPageSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Meu Louvor'), findsOneWidget);
  });
}
