import 'dart:async';

import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/pdf_reader/data/pdfrx_bootstrap.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_prefetch_providers.dart';
import 'package:coldigui/features/pdf_reader/domain/ports/network_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubChecker implements NetworkConnectionChecker {
  _StubChecker({this.unmetered = true});

  final bool unmetered;

  @override
  Future<bool> isUnmeteredConnection() async => unmetered;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<int Function()> pumpPreloader(
    WidgetTester tester, {
    required Future<ColdigomSearchIndex> Function() hydration,
    bool unmetered = true,
  }) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coldigomCatalogHydrationProvider.overrideWith((ref) => hydration()),
          networkConnectionCheckerProvider.overrideWithValue(
            _StubChecker(unmetered: unmetered),
          ),
          pdfrxIdlePreloadSchedulerProvider.overrideWithValue(() => calls++),
        ],
        child: const MaterialApp(
          home: PdfrxIdlePreloader(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    return () => calls;
  }

  testWidgets(
    'não agenda o pdfium enquanto a hidratação do catálogo não resolve',
    (tester) async {
      final gate = Completer<ColdigomSearchIndex>();
      final calls = await pumpPreloader(tester, hydration: () => gate.future);

      await tester.pump(const Duration(seconds: 30));

      expect(
        calls(),
        0,
        reason: 'A11: 5,2 MB de pdfium não competem com o catálogo',
      );

      gate.complete(ColdigomSearchIndex.empty);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('agenda 3 s depois de a hidratação resolver', (tester) async {
    final gate = Completer<ColdigomSearchIndex>();
    final calls = await pumpPreloader(tester, hydration: () => gate.future);

    gate.complete(ColdigomSearchIndex.empty);
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    expect(calls(), 0, reason: 'ainda dentro da janela ociosa');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(calls(), 1);
  });

  testWidgets('erro da hidratação também libera o preload', (tester) async {
    final calls = await pumpPreloader(
      tester,
      hydration: () async => throw Exception('offline'),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(calls(), 1);
  });

  testWidgets('conexão medida não agenda', (tester) async {
    final calls = await pumpPreloader(
      tester,
      hydration: () async => ColdigomSearchIndex.empty,
      unmetered: false,
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(calls(), 0);
  });

  testWidgets('desmontar cancela o timer ocioso', (tester) async {
    final calls = await pumpPreloader(
      tester,
      hydration: () async => ColdigomSearchIndex.empty,
    );

    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(calls(), 0);
  });
}
