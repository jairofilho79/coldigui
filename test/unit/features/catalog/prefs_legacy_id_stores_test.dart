import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/data/legacy_ids/prefs_legacy_id_stores.dart';
import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/pdf_reader/data/datasources/reader_preferences_datasource.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _desconhecido = encodePdfId('ColAdultos/999.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');

LegacyIdResolution _resolution() => LegacyIdResolution(
  queried: {_legadoA, _desconhecido},
  resolved: {_legadoA: _coldigomA},
);

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs;
}

List<Map<String, Object?>> _lastPages(SharedPreferences prefs) =>
    (jsonDecode(prefs.getString(StorageKeys.pdfLastPages)!) as List)
        .cast<Map<String, Object?>>();

void main() {
  group('RecentlyOpenedLegacyIdStore', () {
    test(
      'troca, descarta desconhecido e tira repetidos (mais recente primeiro)',
      () async {
        final prefs = await _prefs({
          StorageKeys.recentlyOpened: jsonEncode([
            _legadoA,
            _coldigomB,
            _desconhecido,
            _coldigomA,
          ]),
        });
        final store = RecentlyOpenedLegacyIdStore(prefs);

        expect(await store.collectLegacyIds(), {_legadoA, _desconhecido});
        expect(await store.rewrite(_resolution()), 1);
        expect(jsonDecode(prefs.getString(StorageKeys.recentlyOpened)!), [
          _coldigomA,
          _coldigomB,
        ]);
      },
    );

    test('sem legado não escreve', () async {
      final prefs = await _prefs({
        StorageKeys.recentlyOpened: jsonEncode([_coldigomB]),
      });

      expect(
        await RecentlyOpenedLegacyIdStore(prefs).rewrite(_resolution()),
        0,
      );
    });
  });

  group('PdfLastPagesLegacyIdStore', () {
    test(
      'colisão com entrada mais nova do id coldigom: fica a mais nova',
      () async {
        final prefs = await _prefs({
          StorageKeys.pdfLastPages: jsonEncode([
            {'id': _legadoA, 'p': 3},
            {'id': _coldigomA, 'p': 7},
            {'id': _desconhecido, 'p': 1},
          ]),
        });
        final store = PdfLastPagesLegacyIdStore(
          ReaderPreferencesDatasource(prefs),
        );

        expect(await store.collectLegacyIds(), {_legadoA, _desconhecido});
        expect(await store.rewrite(_resolution()), 1);
        expect(_lastPages(prefs), [
          {'id': _coldigomA, 'p': 7},
        ]);
      },
    );

    test(
      'colisão em que o legado é o mais recente: fica a página dele',
      () async {
        final prefs = await _prefs({
          StorageKeys.pdfLastPages: jsonEncode([
            {'id': _coldigomA, 'p': 7},
            {'id': _legadoA, 'p': 3},
          ]),
        });

        await PdfLastPagesLegacyIdStore(ReaderPreferencesDatasource(prefs))
            .rewrite(_resolution());

        expect(_lastPages(prefs), [
          {'id': _coldigomA, 'p': 3},
        ]);
        expect(ReaderPreferencesDatasource(prefs).lastPageFor(_coldigomA), 3);
      },
    );
  });

  group('FocusedEntryLegacyIdStore', () {
    Future<(SharedPreferences, FocusedEntryLegacyIdStore)> build(
      String? value,
    ) async {
      final prefs = await _prefs({kCarouselFocusedPdfIdPrefsKey: ?value});
      return (
        prefs,
        FocusedEntryLegacyIdStore(prefs, key: kCarouselFocusedPdfIdPrefsKey),
      );
    }

    test('mantém o sufixo #n da ocorrência', () async {
      final (prefs, store) = await build('$_legadoA#2');

      expect(await store.collectLegacyIds(), {_legadoA});
      expect(await store.rewrite(_resolution()), 1);
      expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), '$_coldigomA#2');
    });

    test('sem sufixo', () async {
      final (prefs, store) = await build(_legadoA);

      await store.rewrite(_resolution());

      expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), _coldigomA);
    });

    test('desconhecido apaga a pref (o foco cai no início)', () async {
      final (prefs, store) = await build('$_desconhecido#1');

      expect(await store.rewrite(_resolution()), 1);
      expect(prefs.containsKey(kCarouselFocusedPdfIdPrefsKey), isFalse);
    });

    test('id coldigom ou pref ausente: nada a fazer', () async {
      final (_, coldigom) = await build('$_coldigomB#1');
      expect(await coldigom.collectLegacyIds(), isEmpty);
      expect(await coldigom.rewrite(_resolution()), 0);

      final (_, ausente) = await build(null);
      expect(await ausente.collectLegacyIds(), isEmpty);
    });
  });
}
