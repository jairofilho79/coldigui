import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/contributions/data/device/device_snapshot_provider.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribute_screen.dart';
import 'package:coldigui/features/contributions/presentation/widgets/device_consent_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_device_snapshot_port.dart';
import '../../../support/pump_app.dart';

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
    'kind bug não mostra o botão de anexar PDF (só imagens) e o texto do limite aparece',
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
