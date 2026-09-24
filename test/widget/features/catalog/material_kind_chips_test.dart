import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/utils/material_kind_selection.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_kind_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpChip(WidgetTester tester, Widget chip) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: chip)),
  ),
);

ShapeBorder familyShape(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(MaterialKindFamilyChip),
            matching: find.byType(Material),
          )
          .first,
    )
    .shape!;

void main() {
  testWidgets(
    'MaterialKindChip: incluído tem borda tracejada; selecionado não',
    (tester) async {
      await pumpChip(
        tester,
        MaterialKindChip(
          label: 'Saxofone alto',
          look: MaterialKindChipLook.included,
          onPressed: () {},
        ),
      );
      final included = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(included.selected, isFalse);
      expect(included.shape, isA<DashedRoundedRectangleBorder>());

      await pumpChip(
        tester,
        MaterialKindChip(
          label: 'Saxofone alto',
          look: MaterialKindChipLook.selected,
          onPressed: () {},
        ),
      );
      final selected = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(selected.selected, isTrue);
      expect(selected.shape, isNot(isA<DashedRoundedRectangleBorder>()));
    },
  );

  testWidgets(
    'MaterialKindFamilyChip: corpo marca, seta abre, contagem visível',
    (tester) async {
      var toggles = 0;
      var expands = 0;
      await pumpChip(
        tester,
        MaterialKindFamilyChip(
          label: 'Saxofone',
          count: 4,
          state: MaterialKindFamilyState.none,
          expanded: false,
          onToggle: () => toggles++,
          onExpand: () => expands++,
          expandTooltip: 'Ver variantes de Saxofone',
        ),
      );
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.text('Saxofone'));
      await tester.tap(find.byTooltip('Ver variantes de Saxofone'));
      expect(toggles, 1);
      expect(expands, 1);
    },
  );

  testWidgets(
    'MaterialKindFamilyChip: refinado é tracejado; marcado é dourado sólido',
    (tester) async {
      Widget chip(MaterialKindFamilyState state) => MaterialKindFamilyChip(
        label: 'Saxofone',
        count: 4,
        state: state,
        expanded: false,
        onToggle: () {},
        onExpand: () {},
        expandTooltip: 'x',
      );
      await pumpChip(tester, chip(MaterialKindFamilyState.refined));
      expect(familyShape(tester), isA<DashedRoundedRectangleBorder>());

      await pumpChip(tester, chip(MaterialKindFamilyState.selected));
      final shape = familyShape(tester) as RoundedRectangleBorder;
      expect(shape, isNot(isA<DashedRoundedRectangleBorder>()));
      expect(shape.side.color, AppColors.gold);
    },
  );

  testWidgets(
    'MaterialKindFamilyChip: semântica expõe nome acessível do corpo e da seta',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpChip(
        tester,
        MaterialKindFamilyChip(
          label: 'Saxofone',
          count: 4,
          state: MaterialKindFamilyState.selected,
          expanded: false,
          onToggle: () {},
          onExpand: () {},
          expandTooltip: 'Ver variantes de Saxofone',
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Saxofone, 4')),
        isSemantics(
          label: 'Saxofone, 4',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Ver variantes de Saxofone')),
        isSemantics(
          label: 'Ver variantes de Saxofone',
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );

      handle.dispose();
    },
  );

  testWidgets('MaterialTypeChip: marcado fica preenchido de vinho', (
    tester,
  ) async {
    await pumpChip(
      tester,
      MaterialTypeChip(
        label: 'PDF',
        count: 71,
        selected: true,
        onPressed: () {},
      ),
    );
    final chip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.selected, isTrue);
    expect(chip.selectedColor, AppColors.title);
    expect(find.text('71'), findsOneWidget);
  });
}
