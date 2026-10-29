import 'dart:typed_data';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/datasources/contribution_draft_local_datasource.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/device/device_snapshot_provider.dart';
import 'package:coldigui/features/contributions/data/providers/contributions_providers.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/domain/validators/attachment_rules.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribute_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_device_snapshot_port.dart';
import '../../../support/pump_app.dart';

base class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile({required this.name, required this.sizeBytes, this.onRead});

  @override
  final String name;
  final int sizeBytes;
  final void Function()? onRead;

  @override
  Uri get uri => Uri.file('/tmp/$name');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => sizeBytes;

  @override
  Future<int?> length() async => sizeBytes;

  @override
  Future<Uint8List> readAsBytes() async {
    onRead?.call();
    return Uint8List(0);
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(Uint8List(0));
}

class _QuotaDs extends ContributionsRemoteDatasource {
  _QuotaDs(this.resetAt) : super(Dio());
  final DateTime resetAt;

  @override
  Future<({String id, ContributionStatus status})> submit({
    required String sessionToken,
    required Map<String, dynamic> payload,
    required List<ContributionAttachment> attachments,
    void Function(int, int)? onProgress,
  }) async => throw ContributionQuotaExceeded(resetAt);
}

class _SentDs extends ContributionsRemoteDatasource {
  _SentDs() : super(Dio());

  @override
  Future<({String id, ContributionStatus status})> submit({
    required String sessionToken,
    required Map<String, dynamic> payload,
    required List<ContributionAttachment> attachments,
    void Function(int, int)? onProgress,
  }) async => (id: 'c1', status: ContributionStatus.pendente);
}

List<Override> _logged() => [
  authStateProvider.overrideWith(
    () => FakeAuthNotifier(
      const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
    ),
  ),
  deviceSnapshotPortProvider.overrideWithValue(FakeDeviceSnapshotPort()),
  connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
];

void main() {
  testWidgets('deslogado vê formulário simplificado com login no lugar de enviar', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ContributeScreen(),
      overrides: [
        authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
        deviceSnapshotPortProvider.overrideWithValue(FakeDeviceSnapshotPort()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Entre com Google para contribuir.'), findsOneWidget);
    // Campo título foi removido da UI
    expect(find.byKey(const Key('contribute-title')), findsNothing);
    // TextArea e checkbox do aparelho presentes
    expect(find.byKey(const Key('contribute-body')), findsOneWidget);
    expect(find.byKey(const Key('contribute-device-checkbox')), findsOneWidget);
    expect(find.byKey(const Key('contribute-send')), findsNothing);
    expect(find.byKey(const Key('contribute-clear-form')), findsOneWidget);
  });

  testWidgets(
    'limpar formulário abre modal de confirmação; cancelar mantém e confirmar limpa',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, const ContributeScreen(), overrides: _logged());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('contribute-body')),
        'Meu relato do problema',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('contribute-clear-form')),
      );
      await tester.tap(find.byKey(const Key('contribute-clear-form')));
      await tester.pumpAndSettle();

      expect(find.text('Limpar formulário?'), findsOneWidget);
      expect(
        find.text(
          'Tem certeza de que deseja limpar todos os campos preenchidos? Esta ação não pode ser desfeita.',
        ),
        findsOneWidget,
      );

      // Cancela: corpo continua preenchido
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Meu relato do problema'), findsOneWidget);

      // Abre modal de novo e confirma
      await tester.tap(find.byKey(const Key('contribute-clear-form')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      expect(find.text('Meu relato do problema'), findsNothing);
    },
  );

  testWidgets(
    'rascunho persiste e é restaurado quando a tela é reconstruída após login',
    (tester) async {
      final sharedStorage = InMemoryContributionDraftLocalDatasource();

      await pumpApp(
        tester,
        const ContributeScreen(),
        overrides: [
          authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
          deviceSnapshotPortProvider.overrideWithValue(
            FakeDeviceSnapshotPort(),
          ),
          contributionDraftLocalDatasourceProvider.overrideWithValue(
            sharedStorage,
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('contribute-body')),
        'Corpo pré-login',
      );
      await tester.pumpAndSettle();

      await pumpApp(
        tester,
        const ContributeScreen(),
        overrides: [
          ..._logged(),
          contributionDraftLocalDatasourceProvider.overrideWithValue(
            sharedStorage,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Corpo pré-login'), findsOneWidget);
      expect(find.byKey(const Key('contribute-send')), findsOneWidget);
    },
  );

  testWidgets(
    'preencher o corpo habilita o botão de enviar diretamente (sem título nem tipo)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, const ContributeScreen(), overrides: _logged());
      await tester.pumpAndSettle();

      final sendBefore = tester.widget<FilledButton>(
        find.byKey(const Key('contribute-send')),
      );
      expect(sendBefore.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('contribute-body')),
        'Encontrei um erro ao rolar a página',
      );
      await tester.pump();

      final sendAfter = tester.widget<FilledButton>(
        find.byKey(const Key('contribute-send')),
      );
      expect(sendAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'checkbox do aparelho vem marcado por padrão e pode ser alternado',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, const ContributeScreen(), overrides: _logged());
      await tester.pumpAndSettle();

      final checkboxFinder = find.byKey(const Key('contribute-device-checkbox'));
      expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);

      // Desmarca pelo checkbox
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

      // Marca de volta tocando na linha inteira
      await tester.tap(find.byKey(const Key('contribute-device-toggle')));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    },
  );

  testWidgets(
    'com alvo, exibe indicador de louvor vinculado',
    (tester) async {
      await pumpApp(
        tester,
        const ContributeScreen(
          target: ContributionTarget(
            source: ContributionSource.coldigom,
            praiseId: 'p1',
          ),
        ),
        overrides: _logged(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Relato vinculado ao louvor'), findsOneWidget);
    },
  );

  testWidgets(
    'seletor de arquivos aceita extensões completas e exibe limite de 32 MB',
    (tester) async {
      Set<String>? capturedExtensions;
      Future<List<PlatformFile>> fakePickFiles({
        required Set<String> allowedExtensions,
      }) async {
        capturedExtensions = allowedExtensions;
        return const [];
      }

      await pumpApp(
        tester,
        ContributeScreen(pickFiles: fakePickFiles),
        overrides: _logged(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anexar arquivo'), findsOneWidget);
      expect(find.textContaining('32 MB'), findsOneWidget);

      await tester.ensureVisible(find.text('Anexar arquivo'));
      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();

      expect(capturedExtensions, kAllowedExtensions);
    },
  );

  testWidgets(
    'anexo maior que 32 MB é recusado sem chegar a ler os bytes (spec §4.2)',
    (tester) async {
      var bytesRead = false;
      Future<List<PlatformFile>> fakePickFiles({
        required Set<String> allowedExtensions,
      }) async => [
        _FakePlatformFile(
          name: 'grande.pdf',
          sizeBytes: 33 * 1024 * 1024,
          onRead: () => bytesRead = true,
        ),
      ];

      await pumpApp(
        tester,
        ContributeScreen(pickFiles: fakePickFiles),
        overrides: _logged(),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Anexar arquivo'));
      await tester.tap(find.text('Anexar arquivo'));
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Acima de 32 MB, envie pelo link do Drive.'),
        ),
        findsOneWidget,
      );
      expect(find.text('grande.pdf'), findsNothing);
      expect(bytesRead, isFalse);
    },
  );

  testWidgets('quota estourada mostra a hora local de resetAt na snackbar', (
    tester,
  ) async {
    final resetAt = DateTime.utc(2026, 9, 18, 3, 0);
    await pumpApp(
      tester,
      const ContributeScreen(),
      overrides: [
        ..._logged(),
        contributionsRemoteDatasourceProvider.overrideWithValue(
          _QuotaDs(resetAt),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('contribute-body')),
      'Texto do problema',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('contribute-send')));
    await tester.tap(find.byKey(const Key('contribute-send')));
    await tester.pump();
    await tester.pump();

    final local = resetAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    expect(find.textContaining('$hh:$mm'), findsOneWidget);
  });

  testWidgets(
    'envio sem tela anterior no histórico (link direto/F5) manda pro Perfil sem lançar',
    (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.contribute,
        routes: [
          GoRoute(
            path: RoutePaths.contribute,
            builder: (_, _) => const ContributeScreen(),
          ),
          GoRoute(
            path: RoutePaths.profile,
            builder: (_, _) => const Scaffold(body: Text('Perfil')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._logged(),
            contributionsRemoteDatasourceProvider.overrideWithValue(_SentDs()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('contribute-body')),
        'Texto para envio',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('contribute-send')));
      await tester.tap(find.byKey(const Key('contribute-send')));
      await tester.pumpAndSettle();

      expect(find.text('Perfil'), findsOneWidget);
    },
  );
}
