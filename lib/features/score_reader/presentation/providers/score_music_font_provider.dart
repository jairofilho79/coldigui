import 'package:crisp_notation/crisp_notation.dart' show Bravura;
import 'package:crisp_notation/crisp_notation.dart' as crisp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fonte musical (Bravura) pronta para o layout e o desenho da partitura.
///
/// Carregada uma vez por app, só quando a primeira partitura abre — o JSON de
/// métricas tem ~0,5 MB e não pesa no arranque de quem nunca abre uma.
final scoreMusicFontProvider = FutureProvider<void>((ref) async {
  await Bravura.load();
  crisp.registerBundledFontLicenses();
});
