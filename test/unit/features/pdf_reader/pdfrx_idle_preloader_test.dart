import 'dart:async';

import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
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

/// Notifier de manifest controlado pelo teste (fica `loading` até liberar).
class _GatedManifestNotifier extends LouvoresManifestNotifier {
  _GatedManifestNotifier(this.gate);

  final Future<LouvoresManifest> Function() gate;

  @override
  Future<LouvoresManifest> build() => gate();
}

void main() {
  final emptyManifest = LouvoresManifest.fromLouvores(const []);

  Future<int Function()> pumpPreloader(
    WidgetTester tester, {
    required Future<LouvoresManifest> Function() manifest,
    bool unmetered = true,
  }) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          louvoresManifestProvider.overrideWith(
            () => _GatedManifestNotifier(manifest),
          ),
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

  testWidgets('não agenda o pdfium enquanto o manifest não resolve', (
    tester,
  ) async {
    final gate = Completer<LouvoresManifest>();
    final calls = await pumpPreloader(tester, manifest: () => gate.future);

    await tester.pump(const Duration(seconds: 30));

    expect(
      calls(),
      0,
      reason: 'A11: 5,2 MB de pdfium não competem com o manifest',
    );

    gate.complete(emptyManifest);
    await tester.pumpAndSettle();
  });

  testWidgets('agenda 3 s depois do manifest resolver', (tester) async {
    final gate = Completer<LouvoresManifest>();
    final calls = await pumpPreloader(tester, manifest: () => gate.future);

    gate.complete(emptyManifest);
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    expect(calls(), 0, reason: 'ainda dentro da janela ociosa');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(calls(), 1);
  });

  testWidgets('erro do manifest também libera o preload', (tester) async {
    final calls = await pumpPreloader(
      tester,
      manifest: () async => throw Exception('offline'),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(calls(), 1);
  });

  testWidgets('conexão medida não agenda', (tester) async {
    final calls = await pumpPreloader(
      tester,
      manifest: () async => emptyManifest,
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
      manifest: () async => emptyManifest,
    );

    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(calls(), 0);
  });
}
