import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_entry.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generatedAt = DateTime(2026, 6, 11);
  final document = LeafletDocument(
    generatedAt: generatedAt,
    entries: const [
      LeafletEntry(index: 1, numero: '203', nome: 'O Fio da Escarlata'),
      LeafletEntry(index: 2, numero: '254', nome: 'Olhai para o alto'),
    ],
  );
  const labels = LeafletContentLabels(
    headerTitle: 'LOUVORES',
    headerDateLine: 'QUINTA-FEIRA 11/06/2026',
    columnNumber: 'NÚMERO',
    columnName: 'NOME DO HINO',
    footerPeace: 'A PAZ DO SENHOR JESUS CRISTO',
    footerGreeting: 'Bom culto!',
  );

  testWidgets('renderiza cabeçalho, colunas, linhas e rodapé PLPCG',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LeafletContent(
              document: document,
              labels: labels,
            ),
          ),
        ),
      ),
    );

    expect(find.text('LOUVORES'), findsOneWidget);
    expect(find.text('QUINTA-FEIRA 11/06/2026'), findsOneWidget);
    expect(find.text('NÚMERO'), findsOneWidget);
    expect(find.text('NOME DO HINO'), findsOneWidget);
    expect(find.text('203'), findsOneWidget);
    expect(find.text('O FIO DA ESCARLATA'), findsOneWidget);
    expect(find.text('254'), findsOneWidget);
    expect(find.text('OLHAI PARA O ALTO'), findsOneWidget);
    expect(find.text('A PAZ DO SENHOR JESUS CRISTO'), findsOneWidget);
    expect(find.text('Bom culto!'), findsOneWidget);
  });
}
