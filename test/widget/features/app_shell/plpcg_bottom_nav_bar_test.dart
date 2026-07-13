import 'package:coldigui/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  PlpcgBottomNavDestination(icon: Icons.event, label: 'Eventos'),
  PlpcgBottomNavDestination(icon: Icons.library_books, label: 'Biblioteca'),
  PlpcgBottomNavDestination(
    svgAsset: 'assets/branding/logo_colorido_no_bg_logo_only.svg',
    label: 'Pesquisar',
  ),
  PlpcgBottomNavDestination(icon: Icons.groups, label: 'Social'),
  PlpcgBottomNavDestination(icon: Icons.person, label: 'Perfil'),
];

void main() {
  testWidgets('mantém itens acima da safe area inferior', (tester) async {
    const bottomInset = 34.0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: bottomInset),
            size: Size(800, 600),
          ),
          child: Scaffold(
            bottomNavigationBar: PlpcgBottomNavBar(
              selectedIndex: 2,
              onDestinationSelected: (_) {},
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );

    final screenBottom = tester.getBottomLeft(find.byType(Scaffold)).dy;
    final rowBottom = tester.getBottomLeft(find.byType(Row).first).dy;

    expect(screenBottom - rowBottom, greaterThanOrEqualTo(bottomInset + 2));
  });

  testWidgets('Pesquisar responde ao toque acima da safe area', (tester) async {
    var tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 34),
            size: Size(800, 600),
          ),
          child: Scaffold(
            bottomNavigationBar: PlpcgBottomNavBar(
              selectedIndex: 0,
              onDestinationSelected: (index) => tappedIndex = index,
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pesquisar'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 2);
  });
}
