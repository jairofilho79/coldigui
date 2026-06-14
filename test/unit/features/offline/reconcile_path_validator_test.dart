import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/utils/reconcile_path_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reconcile_path_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('rejeita HTML disfarçado de PDF', () {
    final file = File('${tempDir.path}/fake.pdf');
    file.writeAsStringSync('<html><body>404</body></html>');

    final result = validatePdfPathsChunk([
      ReconcilePathEntry(pdfId: 'id1', absolutePath: file.path),
    ]);

    expect(result.invalidPdfIds, ['id1']);
    expect(result.validAbsolutePaths, isEmpty);
  });

  test('aceita PDF com magic bytes válidos', () {
    final file = File('${tempDir.path}/valid.pdf');
    file.writeAsBytesSync(
      Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]),
    );

    final result = validatePdfPathsChunk([
      ReconcilePathEntry(pdfId: 'id1', absolutePath: file.path),
    ]);

    expect(result.invalidPdfIds, isEmpty);
    expect(result.validAbsolutePaths, [file.path]);
  });
}
