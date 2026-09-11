import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/pdf_reader/data/datasources/reader_preferences_datasource.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ReaderPreferencesDatasource datasource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    datasource = ReaderPreferencesDatasource(prefs);
  });

  test('defaults são page-fit', () {
    expect(datasource.getFitMode(), PdfFitMode.pageFit);
    final settings = datasource.loadSettings();
    expect(settings.fitMode, PdfFitMode.pageFit);
  });

  group('spreadEnabled (spec A.4 C8)', () {
    test('default é ligado (true)', () {
      expect(datasource.getSpreadEnabled(), isTrue);
      expect(datasource.loadSettings().spreadEnabled, isTrue);
    });

    test('salva e restaura desligado', () async {
      await datasource.saveSpreadEnabled(false);

      expect(datasource.getSpreadEnabled(), isFalse);
      expect(datasource.loadSettings().spreadEnabled, isFalse);
    });

    test('salva e restaura ligado após desligar', () async {
      await datasource.saveSpreadEnabled(false);
      await datasource.saveSpreadEnabled(true);

      expect(datasource.getSpreadEnabled(), isTrue);
    });
  });

  test('salva e restaura fit mode', () async {
    await datasource.saveFitMode(PdfFitMode.pageWidth);
    expect(datasource.getFitMode(), PdfFitMode.pageWidth);
  });

  test('ignora valores inválidos no storage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.pdfPreferredFitMode, 'invalid');

    expect(datasource.getFitMode(), PdfFitMode.pageFit);
  });

  group('última página (LRU)', () {
    test('sem entrada salva devolve null', () {
      expect(datasource.lastPageFor('a'), isNull);
    });

    test('salva e restaura a última página de um pdfId', () async {
      await datasource.saveLastPage('a', 3);
      expect(datasource.lastPageFor('a'), 3);
    });

    test('salvar de novo o mesmo pdfId substitui o valor anterior', () async {
      await datasource.saveLastPage('a', 3);
      await datasource.saveLastPage('a', 7);
      expect(datasource.lastPageFor('a'), 7);
    });

    test('51 ids distintos — o primeiro (mais antigo) sai do LRU', () async {
      for (var i = 0; i < 51; i++) {
        await datasource.saveLastPage('pdf-$i', i + 1);
      }

      expect(datasource.lastPageFor('pdf-0'), isNull);
      expect(datasource.lastPageFor('pdf-1'), 2);
      expect(datasource.lastPageFor('pdf-50'), 51);
    });

    test('JSON corrompido no storage — devolve null sem lançar', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.pdfLastPages, '{not valid json');

      expect(() => datasource.lastPageFor('a'), returnsNormally);
      expect(datasource.lastPageFor('a'), isNull);
    });

    test('JSON válido mas shape errado (não é lista) — devolve null', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.pdfLastPages, '{"a": 1}');

      expect(datasource.lastPageFor('a'), isNull);
    });

    test('entrada malformada na lista é ignorada, resto sobrevive', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.pdfLastPages,
        '[{"id":"a","p":3},{"nope":true},{"id":"b","p":"x"}]',
      );

      expect(datasource.lastPageFor('a'), 3);
      expect(datasource.lastPageFor('b'), isNull);
    });
  });
}
