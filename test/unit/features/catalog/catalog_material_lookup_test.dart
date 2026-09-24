import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

final _plpcgPdfId = encodePdfId('ColAdultos/001.pdf');
final _coldigomPdfId = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomChordId = encodePdfId('assets/praises/p1/m1.chord');
final _coldigomGestureId = encodePdfId('assets/praises/p1/m1.gestures');
final _coldigomAudioId = encodePdfId('assets/praises/p1/m1.mp3');
final _outroAudioId = encodePdfId('assets/praises/p2/m1.mp3');

final _plpcgLouvor = Louvor.fromManifest(
  nome: 'Grande Deus',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: _plpcgPdfId,
);

final _coldigomLouvor = Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: 'Partitura',
  classificacao: 'Balada',
  pdf: 'm1.pdf',
  pdfId: _coldigomPdfId,
  groupId: 'p1',
  source: LouvorDataSource.coldigom,
);

final _chord = ChordMaterial(
  chordId: _coldigomChordId,
  r2Key: 'assets/praises/p1/m1.chord',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Cifra',
  classificacao: 'Balada',
);

final _gesture = GestureMaterial(
  gestureId: _coldigomGestureId,
  r2Key: 'assets/praises/p1/m1.gestures',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Gestos',
  classificacao: 'Balada',
);

AudioTrack _track(String audioId, String groupId) => AudioTrack(
  audioId: audioId,
  r2Key: 'assets/praises/$groupId/m1.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: groupId,
  categoria: 'Áudio',
  classificacao: 'Balada',
  source: LouvorDataSource.coldigom,
);

final _youtube = YoutubeMaterial(
  id: 'yt-1',
  url: 'https://youtu.be/abc',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Vídeo',
  classificacao: 'Balada',
);

const _meta = ColdigomPraiseMetadata(name: 'Comigo habita');

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      louvoresManifestOverride(LouvoresManifest.fromLouvores([_plpcgLouvor])),
    ],
  );
  addTearDown(container.dispose);
  await container.read(louvoresManifestProvider.future);

  container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
    _coldigomLouvor,
  ]);
  container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
    _track(_coldigomAudioId, 'p1'),
  ]);
  container.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords([
    _chord,
  ]);
  container.read(coldigomGestureMaterialsCacheProvider.notifier).mergeGestures([
    _gesture,
  ]);
  container.read(coldigomPraiseMetaCacheProvider.notifier).put('p1', _meta);
  container.read(coldigomYoutubeCacheProvider.notifier).mergeYoutube([
    _youtube,
  ]);
  return container;
}

void main() {
  group('CatalogMaterialLookup', () {
    test(
      'louvor lê o catálogo coldigom; id legado do manifesto não resolve',
      () async {
        final container = await _container();
        final lookup = container.read(catalogMaterialLookupProvider);

        expect(lookup.louvor(_coldigomPdfId), same(_coldigomLouvor));
        expect(
          lookup.louvor(_plpcgPdfId),
          isNull,
          reason: 'o manifesto carregado já não alimenta o lookup',
        );
        expect(lookup.louvor('id-inexistente'), isNull);
      },
    );

    test('audioTrack, chord, praiseMeta e youtube leem os caches', () async {
      final container = await _container();
      final lookup = container.read(catalogMaterialLookupProvider);

      expect(lookup.audioTrack(_coldigomAudioId)?.groupId, 'p1');
      expect(lookup.audioTrack('nao-existe'), isNull);
      expect(lookup.chord(_coldigomChordId), same(_chord));
      expect(lookup.chord('nao-existe'), isNull);
      expect(lookup.gesture(_coldigomGestureId), same(_gesture));
      expect(lookup.gesture('nao-existe'), isNull);
      expect(lookup.praiseMeta('p1'), same(_meta));
      expect(lookup.praiseMeta('p404'), isNull);
      expect(lookup.youtube('p1').single.id, 'yt-1');
      expect(lookup.youtube('p404'), isEmpty);
    });

    test('tracksFor preserva a ordem e ignora ids sem hit', () async {
      final container = await _container();
      container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
        _track(_outroAudioId, 'p2'),
      ]);
      final lookup = container.read(catalogMaterialLookupProvider);

      final tracks = lookup.tracksFor([
        _outroAudioId,
        'sem-hit',
        _coldigomAudioId,
      ]);

      expect(tracks.map((t) => t.audioId).toList(), [
        _outroAudioId,
        _coldigomAudioId,
      ]);
      expect(lookup.tracksFor(const []), isEmpty);
    });

    test('chordsOfGroup lista as cifras do praise por categoria', () async {
      final container = await _container();
      final outraCifra = ChordMaterial(
        chordId: encodePdfId('assets/praises/p1/m2.chord'),
        r2Key: 'assets/praises/p1/m2.chord',
        nome: 'Comigo habita',
        numero: '692',
        groupId: 'p1',
        categoria: 'Cifra I',
        classificacao: 'Balada',
      );
      final cifraDeOutro = ChordMaterial(
        chordId: encodePdfId('assets/praises/p2/m1.chord'),
        r2Key: 'assets/praises/p2/m1.chord',
        nome: 'Outro',
        numero: '1',
        groupId: 'p2',
        categoria: 'Cifra',
        classificacao: 'Balada',
      );
      container.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords([
        outraCifra,
        cifraDeOutro,
      ]);
      final lookup = container.read(catalogMaterialLookupProvider);

      expect(lookup.chordsOfGroup('p1').map((c) => c.categoria), [
        'Cifra',
        'Cifra I',
      ]);
      expect(lookup.chordsOfGroup('p404'), isEmpty);
    });

    test('withPraiseMeta anexa a meta do cache só quando falta', () async {
      final container = await _container();
      final lookup = container.read(catalogMaterialLookupProvider);
      final semMeta = LouvorGroup(
        groupId: 'p1',
        numero: '692',
        nome: 'Comigo habita',
        sections: const [],
      );
      const outraMeta = ColdigomPraiseMetadata(name: 'Já tinha');
      final comMeta = semMeta.withColdigomMeta(outraMeta);
      final forinho = LouvorGroup(
        groupId: 'p404',
        numero: '1',
        nome: 'Sem cache',
        sections: const [],
      );

      expect(lookup.withPraiseMeta(semMeta).coldigomMeta, same(_meta));
      expect(lookup.withPraiseMeta(comMeta).coldigomMeta, same(outraMeta));
      expect(lookup.withPraiseMeta(forinho), same(forinho));
    });
  });
}
