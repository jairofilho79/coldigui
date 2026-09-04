// test/unit/features/catalog/catalog_source_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/data/sources/composite_catalog_source.dart';
import 'package:coldigui/features/catalog/data/sources/plpcg_catalog_source.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:flutter_test/flutter_test.dart';

final _plpcgGroupId = LouvorGroupId.compute(numero: '001', nome: 'Grande Deus');

final _plpcgPdfId = encodePdfId('ColAdultos/001.pdf');
final _plpcgCifraId = encodePdfId('ColAdultos/001-cifra.pdf');

final _plpcgPartitura = Louvor.fromManifest(
  nome: 'Grande Deus',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: _plpcgPdfId,
  groupId: _plpcgGroupId,
);

final _plpcgCifra = Louvor.fromManifest(
  nome: 'Grande Deus',
  numero: '001',
  categoria: 'Cifra nível I',
  classificacao: 'ColAdultos',
  pdf: '001-cifra.pdf',
  pdfId: _plpcgCifraId,
  groupId: _plpcgGroupId,
);

final _coldigomPdfId = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomChordId = encodePdfId('assets/praises/p1/m1.chord');
final _coldigomAudioId = encodePdfId('assets/praises/p1/m1.mp3');

final _coldigomPdf = Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '002',
  categoria: 'Partitura',
  classificacao: 'Country',
  pdf: 'm1.pdf',
  pdfId: _coldigomPdfId,
  groupId: 'p1',
  source: LouvorDataSource.coldigom,
);

final _coldigomChord = ChordMaterial(
  chordId: _coldigomChordId,
  r2Key: 'assets/praises/p1/m1.chord',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Cifra',
  classificacao: 'Country',
);

final _coldigomTrack = AudioTrack(
  audioId: _coldigomAudioId,
  r2Key: 'assets/praises/p1/m1.mp3',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Country',
  source: LouvorDataSource.coldigom,
);

PlpcgCatalogSource _plpcgSource() =>
    PlpcgCatalogSource(catalog: [_plpcgPartitura, _plpcgCifra]);

ColdigomCatalogSource _coldigomSource() => ColdigomCatalogSource(
  louvores: {_coldigomPdfId: _coldigomPdf},
  chords: {_coldigomChordId: _coldigomChord},
  audioTracks: {_coldigomAudioId: _coldigomTrack},
);

void main() {
  group('PlpcgCatalogSource', () {
    test('materialById devolve PdfMaterial do manifest', () async {
      final material = await _plpcgSource().materialById(_plpcgPdfId);

      expect(material, isA<PdfMaterial>());
      expect(material!.id, _plpcgPdfId);
    });

    test('materialById devolve null para id fora do manifest', () async {
      expect(
        await _plpcgSource().materialById(encodePdfId('ColAdultos/999.pdf')),
        isNull,
      );
    });

    test('groupById monta o grupo do manifest', () async {
      final group = await _plpcgSource().groupById(_plpcgGroupId);

      expect(group, isNotNull);
      expect(group!.totalPdfs, 2);
    });

    test('groupForMaterial agrupa irmãos PLPCG', () async {
      final group = await _plpcgSource().groupForMaterial(_plpcgPdfId);

      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
      expect(
        group.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.plpcg),
        isTrue,
      );
    });

    test('não conhece cifra nem áudio Coldigom', () async {
      final source = _plpcgSource();

      expect(await source.materialById(_coldigomChordId), isNull);
      expect(await source.materialById(_coldigomAudioId), isNull);
    });
  });

  group('ColdigomCatalogSource', () {
    test('materialById resolve pdf, cifra e áudio pelo cache', () async {
      final source = _coldigomSource();

      expect(await source.materialById(_coldigomPdfId), isA<PdfMaterial>());
      expect(
        await source.materialById(_coldigomChordId),
        isA<ChordMaterialRef>(),
      );
      expect(await source.materialById(_coldigomAudioId), isA<AudioMaterial>());
    });

    test('materialById devolve null com cache frio', () async {
      expect(
        await const ColdigomCatalogSource().materialById(_coldigomChordId),
        isNull,
      );
    });

    test('groupForMaterial junta PDF, cifra e áudio do praise', () async {
      final group = await _coldigomSource().groupForMaterial(_coldigomChordId);

      expect(group, isNotNull);
      expect(group!.groupId, 'p1');
      expect(group.totalMaterials, 3);
      expect(group.chordMaterials.single.chordId, _coldigomChordId);
      expect(group.audioTracks.single.audioId, _coldigomAudioId);
    });

    test('groupById devolve null para praise desconhecido', () async {
      expect(await _coldigomSource().groupById('p404'), isNull);
    });
  });

  group('CompositeCatalogSource', () {
    CompositeCatalogSource composite() => CompositeCatalogSource(
      plpcg: _plpcgSource(),
      coldigom: _coldigomSource(),
    );

    test('materialById despacha pelo espaço de ids', () async {
      final source = composite();

      final plpcg = await source.materialById(_plpcgPdfId);
      expect(plpcg, isA<PdfMaterial>());
      expect((plpcg! as PdfMaterial).louvor.source, LouvorDataSource.plpcg);

      final chord = await source.materialById(_coldigomChordId);
      expect(chord, isA<ChordMaterialRef>());
    });

    test('groupForMaterial não mistura PLPCG e Coldigom', () async {
      final source = composite();

      final plpcgGroup = await source.groupForMaterial(_plpcgPdfId);
      expect(
        plpcgGroup!.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.plpcg),
        isTrue,
      );

      final coldigomGroup = await source.groupForMaterial(_coldigomPdfId);
      expect(coldigomGroup!.groupId, 'p1');
      expect(
        coldigomGroup.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.coldigom),
        isTrue,
      );
    });

    test('groupById tenta o manifest e cai no cache Coldigom', () async {
      final source = composite();

      expect((await source.groupById(_plpcgGroupId))!.totalPdfs, 2);
      expect((await source.groupById('p1'))!.groupId, 'p1');
      expect(await source.groupById('desconhecido'), isNull);
    });
  });
}
