import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_entry.dart';
import 'package:coldigui/features/leaflet/presentation/utils/leaflet_capture.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = LeafletContentLabels(
    headerDateLine: 'SEGUNDA-FEIRA 14/09/2026',
    columnNumber: 'NÚMERO',
    columnName: 'NOME DO HINO',
    footerPeace: 'A PAZ DO SENHOR JESUS CRISTO',
    footerGreeting: 'Bom culto!',
    shareQrCaption: 'Abrir lista no PLPCG',
  );
  final document = LeafletDocument(
    generatedAt: DateTime(2026, 9, 14),
    entries: const [
      LeafletEntry(index: 1, numero: '055', nome: 'Senhor meu Deus e Pai'),
    ],
    shareUrl: 'https://plpcg.com/?s=060f&n=Culto',
  );

  testWidgets('boundary capturado inclui margem de segurança em volta do folheto',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final overlay = tester.state<OverlayState>(find.byType(Overlay));

    Size? boundarySize;
    Size? contentSize;
    final future = captureLeafletPngBytes(
      overlay,
      document,
      labels,
      capture: (boundaryKey) async {
        // O overlay foi inserido, mas só constrói no próximo frame.
        await tester.pump();
        boundarySize = boundaryKey.currentContext!.size;
        contentSize = tester.getSize(find.byType(LeafletContent));
        return const <int>[];
      },
    );
    await future;

    expect(contentSize!.width, kLeafletContentWidth);
    expect(
      boundarySize!.width,
      kLeafletContentWidth + 2 * kLeafletCaptureMargin,
    );
    expect(
      boundarySize!.height,
      contentSize!.height + 2 * kLeafletCaptureMargin,
    );
  });
}
