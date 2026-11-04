import 'dart:async';

import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_types_for_kind_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/widgets/material_type_preference_control.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  Future<void> pump(
    WidgetTester tester, {
    required List<String> types,
    String? preferredType,
    ValueChanged<String>? onChanged,
    double textScale = 1,
  }) async {
    await pumpApp(
      tester,
      MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: MaterialTypePreferenceControl(
          kindId: 'k1',
          kindName: 'Cifra',
          preferredType: preferredType,
          onChanged: onChanged ?? (_) {},
        ),
      ),
      overrides: [
        materialTypesForKindProvider('k1').overrideWith((ref) async => types),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('formatos ficam visíveis, sem abrir menu', (tester) async {
    await pump(tester, types: const ['pdf', 'chord'], preferredType: 'chord');
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.length, 2);
    expect(chips.where((chip) => chip.selected).single.label, isA<Text>());
    expect(chips.where((chip) => chip.selected).single.avatar, isNull);
    expect(find.text(pt.favoriteMaterialKindsPdfFormat), findsOneWidget);
    expect(find.text(pt.favoriteMaterialKindsChordFormat), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('um toque escolhe o formato sem reordenar a categoria', (
    tester,
  ) async {
    String? changed;
    await pump(
      tester,
      types: const ['pdf', 'chord'],
      preferredType: 'pdf',
      onChanged: (type) => changed = type,
    );
    await tester.tap(find.text(pt.favoriteMaterialKindsChordFormat));
    await tester.pumpAndSettle();
    expect(changed, 'chord');
  });

  testWidgets('formato único mostra seu nome e não oferece seleção', (
    tester,
  ) async {
    await pump(tester, types: const ['pdf']);
    expect(find.text(pt.favoriteMaterialKindsPdfFormat), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('exclui só áudio e YouTube e mantém letra e tipos novos', (
    tester,
  ) async {
    await pump(
      tester,
      types: const ['pdf', 'mp3', 'audio', 'YouTube', 'lyrics', 'video'],
    );
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text(pt.lyricsTab), findsOneWidget);
    expect(find.text('video'), findsOneWidget);
    expect(find.text(pt.audioMaterialSection), findsNothing);
    expect(find.text(pt.youtubeMaterialSection), findsNothing);
  });

  testWidgets('preferência ausente usa o primeiro formato elegível', (
    tester,
  ) async {
    await pump(
      tester,
      types: const ['mp3', 'pdf', 'chord'],
      preferredType: 'video',
    );
    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .singleWhere((chip) => chip.selected);
    expect((selected.label as Text).data, pt.favoriteMaterialKindsPdfFormat);
  });

  testWidgets(
    'lista vazia mostra indisponibilidade, não um controle invisível',
    (tester) async {
      await pump(tester, types: const ['mp3', 'youtube']);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(Text), findsWidgets);
    },
  );

  testWidgets('carregamento e erro têm estado explícito e tentar novamente', (
    tester,
  ) async {
    final pending = Completer<List<String>>();
    var calls = 0;
    await pumpApp(
      tester,
      MaterialTypePreferenceControl(
        kindId: 'k1',
        kindName: 'Cifra',
        onChanged: (_) {},
      ),
      overrides: [
        materialTypesForKindProvider('k1').overrideWith((ref) {
          calls++;
          return pending.future;
        }),
      ],
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.completeError(StateError('rede'));
    await tester.pumpAndSettle();
    expect(find.text(pt.favoriteMaterialKindsRetry), findsOneWidget);
    await tester.tap(find.text(pt.favoriteMaterialKindsRetry));
    await tester.pump();
    expect(calls, greaterThan(1));
  });

  testWidgets('formatos quebram linha a 320px e fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      types: const ['pdf', 'chord', 'gestures', 'lyrics'],
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Wrap), findsOneWidget);
  });
}
