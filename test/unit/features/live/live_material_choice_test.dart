import 'dart:convert';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_material_choice_provider.dart';
import 'package:coldigui/features/live/presentation/providers/live_navigation_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';

final soprano = encodePdfId('assets/praises/p1/soprano.pdf');
final trompete = encodePdfId('assets/praises/p1/trompete.pdf');
final cifra = encodePdfId('assets/praises/p1/cifra.chord');

/// Chave da projeção do consumidor para o louvor `p1` (por louvor, não por
/// material — `livePraiseKeysOf`).
const praiseKey = 'praise:p1';

Louvor _pdf(String pdfId, String nome, String kindId) => Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: nome,
  classificacao: 'Balada',
  pdf: '$nome.pdf',
  pdfId: pdfId,
  groupId: 'p1',
  materialKindId: kindId,
);

String _room() => jsonEncode({
  't': 'room',
  'room': code,
  'status': 'live',
  'ownerName': 'Fulano',
  'role': 'consumer',
  'version': 1,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': [
      {'id': soprano, 'kind': 'pdf'},
    ],
    'focusKey': soprano,
  },
  'leaderPresent': true,
  'viewers': 1,
});

/// O gestor trocou o material do louvor focado (soprano → cifra): o id da
/// entrada e a chave de foco dele mudam, o louvor não.
String _leaderSwappedToChord(int version) => jsonEncode({
  't': 'snapshot',
  'room': code,
  'version': version,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': [
      {'id': cifra, 'kind': 'chord'},
    ],
    'focusKey': cifra,
  },
  'viewers': 1,
});

void main() {
  late ProviderContainer container;
  late FakeLiveTransport transport;
  late List<Set<String>> warmups;
  late List<String> resolvedKeys;
  late List<String> navigated;
  Map<String, int> favorites = const {'k-trompete': 0};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    warmups = [];
    resolvedKeys = [];
    navigated = [];
    container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue(
          (c) => Uri.parse('wss://test/api/live/$c/ws'),
        ),
        // O warmup «chega» com o grupo do louvor: só então o cache tem as
        // duas partituras e o favorito pode ser escolhido.
        liveWarmupProvider.overrideWithValue((ids) async {
          warmups.add(ids.toSet());
          container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
            _pdf(soprano, 'Voz soprano', 'k-soprano'),
            _pdf(trompete, 'Trompete', 'k-trompete'),
          ]);
        }),
        // Resolve como o real: a rota leva o **material projetado** da chave.
        liveFocusResolverProvider.overrideWithValue((key) async {
          resolvedKeys.add(key);
          final item = container
              .read(carouselItemsProvider)
              .firstWhere((i) => i.key == key);
          return '/leitor?key=$key&m=${item.materialId}';
        }),
        liveNavigatorProvider.overrideWithValue(navigated.add),
        // Lido na primeira derivação: um teste que quer outro rank escolhe
        // antes do `join`.
        favoriteMaterialKindRankProvider.overrideWith((ref) => favorites),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => favorites = const {'k-trompete': 0});

  Future<void> joinAndReceiveRoom() async {
    await container.read(liveSessionProvider.notifier).join(code);
    transport.last.emit(_room());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'seguindo, a lista tem a chave do gestor e o material favorito',
    () async {
      await joinAndReceiveRoom();

      expect(warmups.first, {'p1'});
      final entries = container.read(activeEntriesProvider);
      expect(entries.single.key, praiseKey);
      expect(entries.single.id, trompete);
      // O foco resolveu **depois** do warmup — já com o material próprio.
      expect(resolvedKeys, [praiseKey]);
      expect(navigated, ['/leitor?key=$praiseKey&m=$trompete']);
    },
  );

  test('a troca manual pela chave vence o favorito e some ao sair', () async {
    await joinAndReceiveRoom();

    final editor = container.read(activePlaylistEditorProvider.notifier);
    expect(
      await editor.replaceByKey(praiseKey, PlaylistEntry.classified(soprano)),
      isTrue,
    );
    expect(container.read(activeEntriesProvider).single.id, soprano);
    expect(container.read(activeEntriesProvider).single.key, praiseKey);
    expect(
      await editor.replaceByKey(
        'nao-existe',
        PlaylistEntry.classified(soprano),
      ),
      isFalse,
    );

    await container.read(liveSessionProvider.notifier).leave();
    expect(container.read(liveProjectionProvider), isNull);
    expect(container.read(liveMaterialOverridesProvider), isEmpty);
  });

  test('«Guardar cópia» leva o material que o consumidor viu', () async {
    await joinAndReceiveRoom();
    final controller = container.read(liveSessionProvider.notifier);
    expect(controller.snapshotForCopy!.entries.single.id, trompete);

    transport.last.emit(
      jsonEncode({'t': 'ended', 'room': code, 'reason': 'leader'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).phase, LivePhase.ended);
    expect(container.read(liveProjectionProvider), isNull);
    // O snapshot do gestor fica intacto (uma reconexão reprojeta por ele).
    expect(
      container.read(liveSessionProvider).snapshot!.entries.single.id,
      soprano,
    );
    expect(controller.snapshotForCopy!.entries.single.id, trompete);
  });

  group('o gestor troca o material do louvor focado', () {
    test('consumidor com favorito fica no material dele', () async {
      await joinAndReceiveRoom();
      expect(navigated, ['/leitor?key=$praiseKey&m=$trompete']);

      transport.last.emit(_leaderSwappedToChord(2));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // A chave não mudou, o material projetado continua o favorito: nada a
      // navegar — e nem parece um desvio do consumidor.
      expect(navigated, ['/leitor?key=$praiseKey&m=$trompete']);
      expect(container.read(activeEntriesProvider).single.key, praiseKey);
      expect(container.read(activeEntriesProvider).single.id, trompete);
      expect(container.read(liveSessionProvider).followingFocus, isTrue);
    });

    test('consumidor com escolha manual fica nela', () async {
      await joinAndReceiveRoom();
      // O sheet «Material» do consumidor: troca por chave e navega sozinho.
      await container
          .read(activePlaylistEditorProvider.notifier)
          .replaceByKey(praiseKey, PlaylistEntry.classified(soprano));
      await Future<void>.delayed(Duration.zero);

      transport.last.emit(_leaderSwappedToChord(2));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(navigated, ['/leitor?key=$praiseKey&m=$trompete']);
      expect(container.read(activeEntriesProvider).single.id, soprano);
    });

    test('consumidor sem escolha própria acompanha a troca', () async {
      favorites = const {};
      await joinAndReceiveRoom();
      expect(navigated, ['/leitor?key=$praiseKey&m=$soprano']);

      transport.last.emit(_leaderSwappedToChord(2));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(navigated, [
        '/leitor?key=$praiseKey&m=$soprano',
        '/leitor?key=$praiseKey&m=$cifra',
      ]);
      expect(container.read(activeEntriesProvider).single.id, cifra);
      expect(container.read(liveSessionProvider).followingFocus, isTrue);
    });
  });
}
