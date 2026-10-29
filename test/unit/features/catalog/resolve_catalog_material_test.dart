// test/unit/features/catalog/resolve_catalog_material_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_source_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/resolve_catalog_material.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_overrides.dart';

final _plpcgPdfId = encodePdfId('ColAdultos/001.pdf');
final _gestureId = encodePdfId('ColAdultos/001.gestures');
final _chordId = encodePdfId('assets/praises/p1/m1.chord');
final _audioId = encodePdfId('assets/praises/p1/m1.mp3');
final _coldigomPdfId = encodePdfId('assets/praises/p1/m1.pdf');

final _coldigomPdf = Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '002',
  categoria: 'Partitura',
  classificacao: 'Country',
  pdf: 'm1.pdf',
  pdfId: _coldigomPdfId,
  groupId: 'p1',
);

final _chord = ChordMaterial(
  chordId: _chordId,
  r2Key: 'assets/praises/p1/m1.chord',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Cifra',
  classificacao: 'Country',
);

final _track = AudioTrack(
  audioId: _audioId,
  r2Key: 'assets/praises/p1/m1.mp3',
  nome: 'Comigo habita',
  numero: '002',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Country',
);

class _FakeLouvoresCache extends ColdigomLouvoresCacheNotifier {
  @override
  Map<String, Louvor> build() => {_coldigomPdfId: _coldigomPdf};
}

class _FakeChordCache extends ColdigomChordMaterialsCacheNotifier {
  @override
  Map<String, ChordMaterial> build() => {_chordId: _chord};
}

class _FakeAudioCache extends ColdigomAudioTracksCacheNotifier {
  @override
  Map<String, AudioTrack> build() => {_audioId: _track};
}

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      ...standardTestOverrides(),
      coldigomLouvoresCacheProvider.overrideWith(_FakeLouvoresCache.new),
      coldigomChordMaterialsCacheProvider.overrideWith(_FakeChordCache.new),
      coldigomAudioTracksCacheProvider.overrideWith(_FakeAudioCache.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// `WidgetRef` real — a única variante do use case que a produção usa.
Future<WidgetRef> _widgetRef(WidgetTester tester) async {
  final container = await _container();
  late WidgetRef captured;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          captured = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return captured;
}

void main() {
  testWidgets('id legado não resolve', (tester) async {
    final ref = await _widgetRef(tester);

    expect(await resolveCatalogMaterialFromWidget(ref, _plpcgPdfId), isNull);
  });

  testWidgets('resolve PDF do cache Coldigom', (tester) async {
    final ref = await _widgetRef(tester);

    final material = await resolveCatalogMaterialFromWidget(
      ref,
      _coldigomPdfId,
    );

    expect(material, isA<PdfMaterial>());
    expect((material! as PdfMaterial).louvor.pdfId, _coldigomPdfId);
  });

  testWidgets('resolve cifra do cache', (tester) async {
    final ref = await _widgetRef(tester);

    final material = await resolveCatalogMaterialFromWidget(ref, _chordId);

    expect(material, isA<ChordMaterialRef>());
    expect((material! as ChordMaterialRef).chord.chordId, _chordId);
  });

  testWidgets('resolve áudio do cache', (tester) async {
    final ref = await _widgetRef(tester);

    final material = await resolveCatalogMaterialFromWidget(ref, _audioId);

    expect(material, isA<AudioMaterial>());
  });

  testWidgets('gesto e id de YouTube não são endereçáveis', (tester) async {
    final ref = await _widgetRef(tester);

    expect(await resolveCatalogMaterialFromWidget(ref, _gestureId), isNull);
    expect(await resolveCatalogMaterialFromWidget(ref, 'ADmqXpHmVIQ'), isNull);
  });

  test('catalogSourceProvider lê o catálogo coldigom', () async {
    final container = await _container();
    final source = container.read(catalogSourceProvider);

    expect((await source.groupForMaterial(_coldigomPdfId))!.groupId, 'p1');
    expect(await source.materialById(_plpcgPdfId), isNull);
  });
}
