import 'dart:typed_data';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/device/device_snapshot_provider.dart';
import 'package:coldigui/features/contributions/data/providers/contributions_providers.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/domain/validators/attachment_rules.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribute_screen.dart';
import 'package:coldigui/features/contributions/presentation/widgets/device_consent_card.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_device_snapshot_port.dart';
import '../../../support/pump_app.dart';

/// `PlatformFile` de mentira — `lengthSync()` devolve o tamanho sem I/O
/// nenhuma (como um `File`/`Blob` real reportaria) e `readAsBytes()` avisa
/// via [onRead] se chegou a ser chamado. `base class` (não `class` puro):
/// `PlatformFile` em si é `base` — subclasses fora do pacote precisam
/// declarar isso também para manter a garantia de que só se estende, nunca
/// se implementa.
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

/// Datasource de mentira que sempre estoura a quota — usado para checar a
/// hora local na snackbar (spec §6.2/D-quota).
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

/// Datasource de mentira que sempre envia com sucesso — usado para checar a
/// navegação pós-envio sem depender de rede de verdade.
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

/// Praise meta fixa para o teste de prefill — evita depender de rede/cache
/// real dos providers coldigom.
class _FakePraiseMetaNotifier extends ColdigomPraiseMetaCacheNotifier {
  _FakePraiseMetaNotifier(this._map);
  final Map<String, ColdigomPraiseMetadata> _map;
  @override
  Map<String, ColdigomPraiseMetadata> build() => _map;
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
  testWidgets('deslogado vê o convite para entrar', (tester) async {
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
  });

  testWidgets(
    'bug: Enviar só habilita depois de responder sobre o dispositivo',
    (tester) async {
      // Viewport maior que o padrão do `flutter_test` (800×600 lógicos): o
      // formulário completo (spec §6.2 — anexos/links antes do cartão de
      // dispositivo, sem compactação) não cabe em 600px de altura, e o
      // teste precisa tocar o "Sim" do `SegmentedButton` lá embaixo.
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpApp(tester, const ContributeScreen(), overrides: _logged());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bug na app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leitor'));
      await tester.enterText(
        find.byKey(const Key('contribute-title')),
        'Trava',
      );
      await tester.enterText(
        find.byKey(const Key('contribute-body')),
        'Na página 3',
      );
      await tester.pumpAndSettle();
      expect(find.byType(DeviceConsentCard), findsOneWidget);
      expect(find.text('Isto será enviado'), findsOneWidget);
      final sendBefore = tester.widget<FilledButton>(
        find.byKey(const Key('contribute-send')),
      );
      expect(sendBefore.onPressed, isNull);
      await tester.tap(find.text('Sim'));
      await tester.pumpAndSettle();
      final sendAfter = tester.widget<FilledButton>(
        find.byKey(const Key('contribute-send')),
      );
      expect(sendAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'com alvo, «Informação errada» vem selecionada e o seletor de material aparece',
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
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Informação errada'),
      );
      expect(chip.selected, isTrue);
      expect(find.text('Sobre qual material?'), findsOneWidget);
    },
  );

  testWidgets(
    'kind conteúdo mostra o botão de anexar e o texto do limite de 32 MB',
    (tester) async {
      await pumpApp(tester, const ContributeScreen(), overrides: _logged());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conteúdo'));
      await tester.pumpAndSettle();
      expect(find.text('Anexar arquivo'), findsOneWidget);
      expect(find.textContaining('32 MB'), findsOneWidget);
    },
  );

  testWidgets(
    'kind bug restringe o seletor de arquivos a imagens (só screenshot)',
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
      await tester.tap(find.text('Bug na app'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Anexar arquivo'));
      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();

      expect(capturedExtensions, kImageExtensions);
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
      await tester.tap(find.text('Conteúdo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Anexar arquivo'));
      await tester.tap(find.text('Anexar arquivo'));
      // `pump()` simples (não `pumpAndSettle`): a `SnackBar` tem um timer de
      // alguns segundos para sumir sozinha, e `pumpAndSettle` avança o
      // relógio simulado até não sobrar nenhum frame agendado — inclusive
      // o do próprio timer, fechando a `SnackBar` antes do `expect` abaixo
      // rodar. `pump()` sem duração não avança esse relógio.
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
    await tester.enterText(find.byKey(const Key('contribute-title')), 't');
    await tester.enterText(find.byKey(const Key('contribute-body')), 'b');
    // O `pump()` aqui é o que faz o Riverpod reconstruir o botão com
    // `canSend: true` — sem ele, `onPressed` ainda reflete o rascunho de
    // antes do segundo `enterText` (`ConsumerStatefulWidget.build` só
    // reage à mudança de estado no próximo frame, e `enterText` não pede
    // um sozinho).
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('contribute-send')));
    await tester.tap(find.byKey(const Key('contribute-send')));
    // `pump()` simples (não `pumpAndSettle`) — mesmo motivo do teste de
    // anexo grande acima: a `SnackBar` não pode sumir sozinha antes do
    // `expect`.
    await tester.pump();
    await tester.pump();

    // Local, não literal: o horário depende do fuso de quem roda o teste.
    final local = resetAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    expect(find.textContaining('$hh:$mm'), findsOneWidget);
  });

  testWidgets(
    'envio sem tela anterior no histórico (link direto/F5) manda pro Perfil '
    'sem lançar',
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

      await tester.enterText(find.byKey(const Key('contribute-title')), 't');
      await tester.enterText(find.byKey(const Key('contribute-body')), 'b');
      // Sem isto, `canSend` no botão ainda reflete o rascunho de antes do
      // segundo `enterText` — ver o comentário no teste da quota acima.
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('contribute-send')));
      await tester.tap(find.byKey(const Key('contribute-send')));
      await tester.pumpAndSettle();

      expect(find.text('Perfil'), findsOneWidget);
    },
  );

  testWidgets(
    'metadata: escolher «Tom» preenche «Valor atual» com o tom do praise',
    (tester) async {
      await pumpApp(
        tester,
        const ContributeScreen(
          target: ContributionTarget(
            source: ContributionSource.coldigom,
            praiseId: 'p1',
          ),
        ),
        overrides: [
          ..._logged(),
          coldigomPraiseMetaCacheProvider.overrideWith(
            () => _FakePraiseMetaNotifier({
              'p1': const ColdigomPraiseMetadata(name: 'Nome', tonality: 'Dm'),
            }),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Título, número, tom…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('contribute-metadata-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tom').last);
      await tester.pumpAndSettle();
      expect(find.text('Dm'), findsOneWidget);
    },
  );
}
