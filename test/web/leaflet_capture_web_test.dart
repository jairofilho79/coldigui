@TestOn('browser')
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coldigui/features/leaflet/presentation/utils/leaflet_image_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Codificação PNG do folheto no engine web real (rodar com `--wasm`).
///
/// No skwasm o PNG é rasterizado no mesmo canvas que desenha os frames da
/// app; com algo animando (o sheet de compartilhar fechando), um frame podia
/// devolver o canvas ao tamanho da janela no meio da codificação e o PNG
/// saía com o tamanho da janela — folheto cortado. Medido antes da correção:
/// 14 de 200 `toByteData(png)` seguidos saíram 2400x1800 (a view) em vez de
/// 1881x1368.
void main() {
  // Frames reais: o spinner precisa animar durante a codificação.
  LiveTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('encodePngMatchingImage resiste a frames concorrentes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1881, 1368),
      Paint()..color = const Color(0xFF4A2C2A),
    );
    final image = await recorder.endRecording().toImage(1881, 1368);

    final wrong = <String>[];
    for (var i = 0; i < 100; i++) {
      final bytes = await encodePngMatchingImage(image);
      final png = pngDimensions(ByteData.sublistView(bytes));
      if (png.width != 1881 || png.height != 1368) {
        wrong.add('${png.width}x${png.height}');
      }
    }
    image.dispose();
    await tester.pumpWidget(const SizedBox());

    expect(wrong, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
