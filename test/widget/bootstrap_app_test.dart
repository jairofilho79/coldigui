import '../support/fakes/fake_isar.dart';
import 'dart:async';
import 'package:coldigui/app.dart';
import 'package:coldigui/bootstrap_app.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  Future<void> pumpBootstrap(
    WidgetTester tester,
    Future<Isar> Function() opener,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarOpenerProvider.overrideWithValue(opener)],
        child: const BootstrapApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('monta ColdiguiApp enquanto o Isar ainda está abrindo', (
    tester,
  ) async {
    final completer = Completer<Isar>();
    await pumpBootstrap(tester, () => completer.future);

    expect(
      find.byType(ColdiguiApp),
      findsOneWidget,
      reason: 'A8: o app não espera o Isar para montar',
    );

    completer.complete(FakeIsar());
    await tester.pumpAndSettle();
  });

  testWidgets('mantém ColdiguiApp quando o Isar abre', (tester) async {
    await pumpBootstrap(tester, () async => FakeIsar());
    await tester.pumpAndSettle();

    expect(find.byType(ColdiguiApp), findsOneWidget);
  });

  testWidgets('mantém ColdiguiApp em modo degradado (erro do Isar)', (
    tester,
  ) async {
    await pumpBootstrap(tester, () async => throw StateError('sem OPFS'));
    await tester.pumpAndSettle();

    expect(find.byType(ColdiguiApp), findsOneWidget);
  });
}
