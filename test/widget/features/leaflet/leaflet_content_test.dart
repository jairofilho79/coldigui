import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_entry.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    headerDateLine: 'QUINTA-FEIRA 11/06/2026',
    columnNumber: 'NÚMERO',
    columnName: 'NOME DO HINO',
    footerPeace: 'A PAZ DO SENHOR JESUS CRISTO',
    footerGreeting: 'Bom culto!',
    shareQrCaption: 'Abrir lista no PLPCG',
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

    expect(find.bySemanticsLabel('PLPCG'), findsOneWidget);
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

  testWidgets('sem shareUrl não desenha QR', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: LeafletContent(document: document, labels: labels),
    ))));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Abrir lista no PLPCG'), findsNothing);
  });

  testWidgets('com shareUrl desenha QR, legenda e o link', (tester) async {
    final comQr = LeafletDocument(
      generatedAt: generatedAt,
      entries: document.entries,
      shareUrl: 'https://plpcg.com/?s=1a2f-0000&n=Culto',
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: LeafletContent(document: comQr, labels: labels),
    ))));
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    // `QrImageView.data` não tem getter público (qr_flutter 4.1.0);
    // `semanticsLabel` carrega o mesmo link (ver `_ShareQrBand`).
    expect(qr.semanticsLabel, 'https://plpcg.com/?s=1a2f-0000&n=Culto');
    expect(find.text('Abrir lista no PLPCG'), findsOneWidget);
    expect(find.text('plpcg.com/?s=1a2f-0000&n=Culto'), findsOneWidget);
  });
}
