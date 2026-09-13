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
  }) async {
    await pumpApp(
      tester,
      MaterialTypePreferenceControl(
        kindId: 'k1',
        kindName: 'Cifra',
        preferredType: preferredType,
        onChanged: onChanged ?? (_) {},
      ),
      overrides: [
        materialTypesForKindProvider('k1').overrideWith((ref) async => types),
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder tooltipButton() => find.byWidgetPredicate(
    (w) =>
        w is IconButton &&
        w.tooltip == pt.favoriteMaterialKindsTypePreferenceTooltip,
  );

  testWidgets('sem types disponíveis não mostra nada', (tester) async {
    await pump(tester, types: const []);
    expect(find.byType(Icon), findsNothing);
    expect(tooltipButton(), findsNothing);
  });

  testWidgets('um único type mostra ícone estático, sem botão', (tester) async {
    await pump(tester, types: const ['pdf']);
    expect(find.byType(Icon), findsOneWidget);
    expect(tooltipButton(), findsNothing);
  });

  testWidgets('mais de um type mostra botão tocável com o preferido', (
    tester,
  ) async {
    await pump(tester, types: const ['pdf', 'chord'], preferredType: 'chord');
    expect(tooltipButton(), findsOneWidget);
  });

  testWidgets('tocar abre o menu ordenável só com os types disponíveis', (
    tester,
  ) async {
    await pump(tester, types: const ['pdf', 'chord']);
    await tester.tap(tooltipButton());
    await tester.pumpAndSettle();

    expect(
      find.text(pt.favoriteMaterialKindsTypePreferenceTitle('Cifra')),
      findsOneWidget,
    );
    expect(find.text(pt.pdfMaterialSection), findsOneWidget);
    expect(find.text(pt.chordMaterialSection), findsOneWidget);
    expect(find.text(pt.audioMaterialSection), findsNothing);
  });

  testWidgets('arrastar o 2º type para o topo avisa o novo preferido', (
    tester,
  ) async {
    String? changedTo;
    await pump(
      tester,
      types: const ['pdf', 'chord'],
      preferredType: 'pdf',
      onChanged: (type) => changedTo = type,
    );
    await tester.tap(tooltipButton());
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final from = tester.getCenter(handles.at(1));
    final to = tester.getCenter(handles.at(0));
    final drag = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveBy(to - from);
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(changedTo, 'chord');
  });
}
