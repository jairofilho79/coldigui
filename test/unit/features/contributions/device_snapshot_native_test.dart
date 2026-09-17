import 'dart:ui' show Size;

import 'package:coldigui/features/contributions/data/device/device_snapshot_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collect() nunca falha por causa do plugin de package_info — degrada para valores desconhecidos', () async {
    // Na VM de teste Platform.isAndroid/isIOS são falsos, então só o seam
    // de package_info é exercitado aqui; o ramo device_info_plus (que
    // também tem try/catch) fica coberto pela leitura do código.
    final port = NativeDeviceSnapshotPort(
      loadPackageInfo: () =>
          throw StateError('canal de plataforma indisponível'),
    );

    final snapshot = await port.collect(
      screen: const Size(400, 800),
      pixelRatio: 2,
      locale: 'pt',
      online: true,
    );

    expect(snapshot.appVersion, 'desconhecida');
    expect(snapshot.buildNumber, '0');
    expect(snapshot.manufacturer, isNull);
    expect(snapshot.model, isNull);
    expect(snapshot.osVersion, isNull);
  });
}
