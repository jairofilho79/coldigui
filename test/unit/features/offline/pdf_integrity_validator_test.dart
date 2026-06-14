import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/utils/pdf_integrity_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_integrity_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('aceita arquivo com magic bytes %PDF', () async {
    final file = File('${tempDir.path}/valid.pdf');
    await file.writeAsBytes(Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]));

    expect(await PdfIntegrityValidator.isValidPdfFile(file.path), isTrue);
    expect(PdfIntegrityValidator.isValidPdfFileSync(file.path), isTrue);
  });

  test('rejeita HTML com tamanho > 0', () async {
    final file = File('${tempDir.path}/fake.pdf');
    await file.writeAsString('<html><body>error</body></html>');

    expect(await PdfIntegrityValidator.isValidPdfFile(file.path), isFalse);
    expect(PdfIntegrityValidator.isValidPdfFileSync(file.path), isFalse);
  });

  test('rejeita arquivo inexistente ou vazio', () async {
    final missing = '${tempDir.path}/missing.pdf';
    final empty = File('${tempDir.path}/empty.pdf');
    await empty.writeAsBytes(Uint8List(0));

    expect(await PdfIntegrityValidator.isValidPdfFile(missing), isFalse);
    expect(await PdfIntegrityValidator.isValidPdfFile(empty.path), isFalse);
  });
}
