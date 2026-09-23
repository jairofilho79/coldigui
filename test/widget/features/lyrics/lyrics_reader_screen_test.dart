import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_data_providers.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/lyrics/domain/entities/lyrics_reader_font_size.dart';
import 'package:coldigui/features/lyrics/presentation/pages/lyrics_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';

/// Datasource só de memória: o leitor lê por `praiseId`, nada mais.
class _MemoryCatalog extends ColdigomCatalogLocalDatasource {
  const _MemoryCatalog(this.rows) : super(null);

  final Map<String, ColdigomPraiseCache> rows;

  @override
  ColdigomPraiseCache? findByPraiseIdSync(String praiseId) => rows[praiseId];
}

/// Catálogo em memória já semeado (C6: sem Isar).
class _SeededMemoryCatalog extends ColdigomInMemoryCatalogNotifier {
  _SeededMemoryCatalog(this._rows);

  final List<ColdigomPraiseCache> _rows;

  @override
  List<ColdigomPraiseCache> build() => _rows;
}

ColdigomPraiseCache _row(String lyrics) => ColdigomPraiseCache()
  ..praiseId = 'p1'
  ..number = '001'
  ..name = 'Ainda há tempo'
  ..author = ''
  ..rhythm = ''
  ..tonality = ''
  ..category = ''
  ..tags = const []
  ..lyrics = lyrics
  ..materialsJson = '[]'
  ..searchTokens = '';

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required String lyrics,
  Map<String, String>? queryParams,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  await pumpApp(
    tester,
    LyricsReaderScreen(
      queryParams:
          queryParams ?? {'praiseId': 'p1', 'titulo': 'Ainda há tempo'},
    ),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      coldigomCatalogLocalDatasourceProvider.overrideWithValue(
        _MemoryCatalog({'p1': _row(lyrics)}),
      ),
    ],
  );
  await tester.pump();
  return prefs;
}

void main() {
  testWidgets('mostra o texto da letra lido do Isar', (tester) async {
    await _pump(tester, lyrics: 'Ainda há tempo\nde voltar ao Senhor');

    expect(find.text('Ainda há tempo'), findsOneWidget);
    expect(find.textContaining('de voltar ao Senhor'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('A+ / A− mudam o corpo e persistem a preferência', (
    tester,
  ) async {
    final prefs = await _pump(tester, lyrics: 'texto');

    TextStyle styleOf() =>
        tester.widget<SelectableText>(find.byType(SelectableText)).style!;
    expect(styleOf().fontSize, LyricsReaderFontSize.initial);

    await tester.tap(find.byTooltip('Aumentar letra'));
    await tester.pump();
    expect(
      styleOf().fontSize,
      LyricsReaderFontSize.initial + LyricsReaderFontSize.step,
    );
    expect(
      prefs.getDouble(StorageKeys.lyricsReaderFontSize),
      LyricsReaderFontSize.initial + LyricsReaderFontSize.step,
    );

    await tester.tap(find.byTooltip('Diminuir letra'));
    await tester.pump();
    expect(styleOf().fontSize, LyricsReaderFontSize.initial);
  });

  testWidgets('praise sem letra ou desconhecido mostra o vazio', (
    tester,
  ) async {
    await _pump(tester, lyrics: '', queryParams: {'praiseId': 'zz'});

    expect(find.text('Este louvor não tem letra guardada'), findsOneWidget);
  });

  testWidgets('sem Isar lê a letra das linhas em memória', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await pumpApp(
      tester,
      const LyricsReaderScreen(queryParams: {'praiseId': 'p1'}),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomCatalogLocalDatasourceProvider.overrideWithValue(
          const ColdigomCatalogLocalDatasource.unavailable(),
        ),
        coldigomInMemoryCatalogProvider.overrideWith(
          () => _SeededMemoryCatalog([_row('Letra só em memória')]),
        ),
      ],
    );
    await tester.pump();

    expect(find.textContaining('Letra só em memória'), findsOneWidget);
    expect(find.text('Ainda há tempo'), findsOneWidget);
  });
}
