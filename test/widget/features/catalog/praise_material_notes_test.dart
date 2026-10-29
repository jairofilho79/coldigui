import 'package:coldigui/features/catalog/presentation/widgets/praise_materials_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTitle({
    required Size screenSize,
    required String categoria,
    required String? notes,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: Scaffold(
          body: Center(
            child: PraiseMaterialTitle(
              categoria: categoria,
              notes: notes,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renderiza nota ao lado do nome em telas maiores (>= 600px)', (tester) async {
    const wideSize = Size(800, 600);
    tester.view.physicalSize = wideSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTitle(
      screenSize: wideSize,
      categoria: 'Coro',
      notes: 'Cifrado',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Coro'), findsOneWidget);
    expect(find.text('Cifrado'), findsOneWidget);

    // Em telas largas, o container do título usa Row
    final rowFinder = find.ancestor(
      of: find.text('Cifrado'),
      matching: find.byType(Row),
    );
    expect(rowFinder, findsOneWidget);
  });

  testWidgets('renderiza nota embaixo do nome em telas menores (< 600px)', (tester) async {
    const smallSize = Size(400, 800);
    tester.view.physicalSize = smallSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTitle(
      screenSize: smallSize,
      categoria: 'Trombone',
      notes: 'I',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Trombone'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);

    // Em telas estreitas, o container do título usa Column
    final columnFinder = find.ancestor(
      of: find.text('I'),
      matching: find.byType(Column),
    );
    expect(columnFinder, findsOneWidget);
  });

  testWidgets('sem nota renderiza apenas Text simples', (tester) async {
    await tester.pumpWidget(buildTitle(
      screenSize: const Size(800, 600),
      categoria: 'Flauta',
      notes: null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Flauta'), findsOneWidget);
    expect(find.byType(Row), findsNothing);
    expect(find.byType(Column), findsNothing);
  });
}
