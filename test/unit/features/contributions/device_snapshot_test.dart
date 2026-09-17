import 'package:coldigui/features/contributions/domain/entities/device_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snap = DeviceSnapshot(
    appVersion: '2.1.0',
    buildNumber: '45',
    platform: 'android',
    locale: 'pt',
    screenW: 1080,
    screenH: 2340,
    pixelRatio: 2.75,
    online: true,
    pwaStandalone: false,
    manufacturer: 'Samsung',
    model: 'SM-A515F',
    osVersion: '13',
  );

  test('toJson em snake_case, sem chaves nulas', () {
    expect(snap.toJson(), {
      'app_version': '2.1.0',
      'build_number': '45',
      'platform': 'android',
      'locale': 'pt',
      'screen_w': 1080,
      'screen_h': 2340,
      'pixel_ratio': 2.75,
      'online': true,
      'pwa_standalone': false,
      'manufacturer': 'Samsung',
      'model': 'SM-A515F',
      'os_version': '13',
    });
  });

  test('humanLines mostra o que vai ser enviado, sem campos vazios', () {
    final labels = snap.humanLines().map((l) => l.$1).toList();
    expect(
      labels,
      containsAll(['App', 'Plataforma', 'Dispositivo', 'Sistema', 'Tela']),
    );
    expect(labels, isNot(contains('Navegador')));
  });
}
