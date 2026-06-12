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

  test('salva e restaura fit mode', () async {
    await datasource.saveFitMode(PdfFitMode.pageWidth);
    expect(datasource.getFitMode(), PdfFitMode.pageWidth);
  });

  test('ignora valores inválidos no storage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.pdfPreferredFitMode, 'invalid');

    expect(datasource.getFitMode(), PdfFitMode.pageFit);
  });
}
