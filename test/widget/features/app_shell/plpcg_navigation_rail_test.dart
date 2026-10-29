import 'package:coldigui/core/widgets/light_beam.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/plpcg_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  PlpcgBottomNavDestination(icon: Icons.library_books, label: 'Biblioteca'),
  PlpcgBottomNavDestination(
    svgAsset: 'assets/branding/logo_colorido_no_bg_logo_only.svg',
    label: 'Pesquisar',
  ),
  PlpcgBottomNavDestination(icon: Icons.playlist_play, label: 'Listas'),
];

Widget _buildRail({
  required int selectedIndex,
  required ValueChanged<int> onDestinationSelected,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1200, 800)),
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlpcgNavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: _destinations,
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renderiza um item por destino, com ícone e rótulo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRail(selectedIndex: 0, onDestinationSelected: (_) {}),
    );

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Pesquisar'), findsOneWidget);
    expect(find.text('Listas'), findsOneWidget);
    expect(find.byIcon(Icons.library_books), findsOneWidget);
    expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('não usa o NavigationRail do Material', (tester) async {
    await tester.pumpWidget(
      _buildRail(selectedIndex: 0, onDestinationSelected: (_) {}),
    );

    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('item selecionado mostra o LightBeam dourado sob o rótulo', (
    tester,
  ) async {
    const selectedIndex = 1;
    await tester.pumpWidget(
      _buildRail(selectedIndex: selectedIndex, onDestinationSelected: (_) {}),
    );
    await tester.pumpAndSettle();

    final beams = find.byType(LightBeam);
    expect(beams, findsNWidgets(_destinations.length));

    for (var i = 0; i < _destinations.length; i++) {
      final opacityFinder = find
          .ancestor(of: beams.at(i), matching: find.byType(Opacity))
          .first;
      final opacity = tester.widget<Opacity>(opacityFinder).opacity;
      if (i == selectedIndex) {
        expect(opacity, 1.0, reason: 'aba ativa mostra o feixe por completo');
      } else {
        expect(opacity, 0.0, reason: 'abas inativas escondem o feixe');
      }
    }
  });

  testWidgets('tocar um item chama onDestinationSelected com o índice', (
    tester,
  ) async {
    var tappedIndex = -1;

    await tester.pumpWidget(
      _buildRail(
        selectedIndex: 0,
        onDestinationSelected: (index) => tappedIndex = index,
      ),
    );

    await tester.tap(find.text('Listas'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 2);
  });
}
