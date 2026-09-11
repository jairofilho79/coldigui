import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

AudioTrack _track(String id, {String groupId = 'g1'}) => AudioTrack(
  audioId: id,
  r2Key: 'assets/praises/$id.mp3',
  nome: id,
  numero: '001',
  groupId: groupId,
  categoria: 'Áudio',
  classificacao: 'Coro',
);

CarouselItem _audioItem(String id, int index) => CarouselItem(
  materialId: id,
  kind: MaterialKind.audio,
  index: index,
  key: id,
  numero: '001',
  nome: id,
  categoria: 'Áudio',
  classificacao: 'Coro',
);

void main() {
  group('queueForTrack', () {
    final a = _track('a');
    final b = _track('b');
    final c = _track('c', groupId: 'g2');

    test('prefere a lista quando a faixa está nela', () {
      final queue = queueForTrack(
        track: b,
        groupTracks: [b, c],
        activeQueue: [a, b],
      );

      expect(queue.map((t) => t.audioId), ['a', 'b']);
    });

    test('cai no grupo quando a faixa não está na lista', () {
      final queue = queueForTrack(
        track: c,
        groupTracks: [b, c],
        activeQueue: [a, b],
      );

      expect(queue.map((t) => t.audioId), ['b', 'c']);
    });

    test('lista vazia cai no grupo', () {
      final queue = queueForTrack(
        track: b,
        groupTracks: [b, c],
        activeQueue: const [],
      );

      expect(queue.map((t) => t.audioId), ['b', 'c']);
    });
  });

  group('activeListAudioQueue', () {
    final a = _track('a');
    final c = _track('c');

    List<Override> overrides() => [
      audioFaceItemsProvider.overrideWithValue([
        _audioItem('a', 0),
        // `b` não está em cache — a fila pula, não fura.
        _audioItem('b', 1),
        _audioItem('c', 2),
      ]),
      catalogMaterialLookupProvider.overrideWithValue(
        CatalogMaterialLookup(audioTracksById: {'a': a, 'c': c}),
      ),
    ];

    test('a variante Ref segue a ordem das entradas de áudio', () {
      final probe = Provider<List<AudioTrack>>(activeListAudioQueueOf);
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      expect(container.read(probe).map((t) => t.audioId), ['a', 'c']);
    });

    testWidgets('segue a ordem das entradas de áudio', (tester) async {
      late List<AudioTrack> queue;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: Consumer(
            builder: (context, ref, _) {
              queue = activeListAudioQueue(ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(queue.map((t) => t.audioId), ['a', 'c']);
    });

    testWidgets('face de áudio vazia devolve fila vazia', (tester) async {
      late List<AudioTrack> queue;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioFaceItemsProvider.overrideWithValue(const []),
            catalogMaterialLookupProvider.overrideWithValue(
              CatalogMaterialLookup(audioTracksById: {'a': a}),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              queue = activeListAudioQueue(ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(queue, isEmpty);
    });
  });
}
