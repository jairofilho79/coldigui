import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/leaflet/domain/exceptions/empty_leaflet_exception.dart';
import 'package:coldigui/features/leaflet/domain/usecases/generate_leaflet_from_entries.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generatedAt = DateTime(2026, 6, 11);

  GenerateLeafletFromEntries useCaseWith(CatalogMaterialLookup lookup) {
    return GenerateLeafletFromEntries(lookup: () => lookup);
  }

  test('lista só de áudio gera folheto com número e nome', () {
    final lookup = const CatalogMaterialLookup(
      audioTracksById: {
        'audio-1': AudioTrack(
          audioId: 'audio-1',
          r2Key: 'assets/praises/a/audio.mp3',
          nome: 'X',
          numero: '5',
          groupId: 'g1',
          categoria: 'Áudio',
          classificacao: '',
        ),
      },
    );

    final doc = useCaseWith(lookup)(
      entries: [PlaylistEntry.audio('audio-1')],
      now: generatedAt,
    );

    expect(doc.generatedAt, generatedAt);
    expect(doc.entries.length, 1);
    expect(doc.entries[0].numero, '5');
    expect(doc.entries[0].nome, 'X');
  });

  test('PDF + áudio do mesmo louvor (groupId) vira uma linha', () {
    final lookup = CatalogMaterialLookup(
      plpcgLouvoresByPdfId: {
        'pdf-1': Louvor.fromManifest(
          nome: 'Louvor A',
          numero: '001',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
          pdf: 'a.pdf',
          pdfId: 'pdf-1',
          groupId: 'g1',
        ),
      },
      audioTracksById: const {
        'audio-1': AudioTrack(
          audioId: 'audio-1',
          r2Key: 'assets/praises/a/audio.mp3',
          nome: 'Louvor A (áudio)',
          numero: '001',
          groupId: 'g1',
          categoria: 'Áudio',
          classificacao: '',
        ),
      },
    );

    final doc = useCaseWith(lookup)(
      entries: [
        PlaylistEntry.classified('pdf-1'),
        PlaylistEntry.audio('audio-1'),
      ],
      now: generatedAt,
    );

    expect(doc.entries.length, 1);
    expect(doc.entries[0].numero, '001');
    expect(doc.entries[0].nome, 'Louvor A');
  });

  test('ordem preservada — primeira ocorrência de cada grupo, na ordem', () {
    final lookup = CatalogMaterialLookup(
      plpcgLouvoresByPdfId: {
        'pdf-a': Louvor.fromManifest(
          nome: 'Louvor A',
          numero: '001',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
          pdf: 'a.pdf',
          pdfId: 'pdf-a',
          groupId: 'ga',
        ),
        'pdf-b': Louvor.fromManifest(
          nome: 'Louvor B',
          numero: '002',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
          pdf: 'b.pdf',
          pdfId: 'pdf-b',
          groupId: 'gb',
        ),
      },
    );

    final doc = useCaseWith(lookup)(
      entries: [
        PlaylistEntry.classified('pdf-b'),
        PlaylistEntry.classified('pdf-a'),
        PlaylistEntry.classified('pdf-b'),
      ],
      now: generatedAt,
    );

    expect(doc.entries.map((e) => e.nome), ['Louvor B', 'Louvor A']);
    expect(doc.entries.map((e) => e.index), [1, 2]);
  });

  test('entrada sem lookup mostra o id como nome e número vazio', () {
    final doc = useCaseWith(const CatalogMaterialLookup())(
      entries: [PlaylistEntry.classified('desconhecido.pdf')],
      now: generatedAt,
    );

    expect(doc.entries.length, 1);
    expect(doc.entries[0].numero, '');
    expect(doc.entries[0].nome, 'desconhecido.pdf');
  });

  test('duas entradas sem lookup e ids diferentes não deduplicam', () {
    final doc = useCaseWith(const CatalogMaterialLookup())(
      entries: [
        PlaylistEntry.classified('a.pdf'),
        PlaylistEntry.classified('b.pdf'),
      ],
      now: generatedAt,
    );

    expect(doc.entries.map((e) => e.nome), ['a.pdf', 'b.pdf']);
  });

  test('lança EmptyLeafletException quando entries vazio', () {
    final useCase = useCaseWith(const CatalogMaterialLookup());

    expect(
      () => useCase(entries: const [], now: generatedAt),
      throwsA(isA<EmptyLeafletException>()),
    );
  });
}
