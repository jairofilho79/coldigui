import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late GestureFigureStoreNative store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gesture_figures_');
    store = GestureFigureStoreNative(
      getApplicationDocumentsDirectory: () async => tempDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('gestureFigureFileName saneia a chave', () {
    expect(
      gestureFigureFileName('assets/cia/gestures/c687580e7682.png'),
      'assets_cia_gestures_c687580e7682.png',
    );
    expect(gestureFigureFileName('a b/ç.gif'), 'a_b__.gif');
  });

  test('read devolve null antes de escrever', () async {
    expect(await store.read('assets/cia/gestures/x.png'), isNull);
  });

  test('write grava em plpcg_gestures/figures e read devolve os bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await store.write('assets/cia/gestures/x.png', bytes);

    expect(await store.read('assets/cia/gestures/x.png'), bytes);
    expect(
      File('${tempDir.path}/plpcg_gestures/figures/assets_cia_gestures_x.png').existsSync(),
      isTrue,
    );
    expect(
      Directory('${tempDir.path}/plpcg_gestures/figures').listSync().any((f) => f.path.endsWith('.tmp')),
      isFalse,
    );
  });

  test('deleteAll apaga tudo e read volta a null', () async {
    await store.write('k.png', Uint8List.fromList([9]));
    await store.deleteAll();
    expect(await store.read('k.png'), isNull);
  });
}
